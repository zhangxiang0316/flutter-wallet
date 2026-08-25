import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/ripemd160.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:solana/solana.dart';
import 'package:sui/sui.dart';
import 'package:aptos/aptos.dart' as aptos;

import '../adapters/chain_adapter.dart';
import '../adapters/chain_adapter_registry.dart';
import '../adapters/chain_operation_registry.dart';
import '../constants/crypto_constants.dart';
import '../models/chain_balance.dart';
import '../models/evm_transaction_draft.dart';
import '../models/wallet_account.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_key_material.dart';
import '../utils/rpc_retry_helper.dart';
import 'crypto/wallet_crypto_service.dart';

part 'transfer/evm_wallet_transfer.dart';
part 'transfer/tron_wallet_transfer.dart';
part 'transfer/tron_transaction_validator.dart';
part 'transfer/solana_wallet_transfer.dart';
part 'transfer/bitcoin_wallet_transfer.dart';
part 'transfer/sui_wallet_transfer.dart';
part 'transfer/aptos_wallet_transfer.dart';

class ChainTransferRequest {
  const ChainTransferRequest({
    required this.privateKeyHex,
    required this.asset,
    required this.toAddress,
    required this.amount,
    this.signingKeyBytes,
    this.evmDraft,
  });

  final String privateKeyHex;
  final List<int>? signingKeyBytes;
  final ChainBalance asset;
  final String toAddress;
  final String amount;
  final EvmTransactionDraft? evmDraft;
}

typedef ChainTransferOperation =
    Future<String> Function(ChainTransferRequest request);

typedef ChainFeeEstimator =
    Future<TransferFeeEstimate> Function({
      required ChainBalance asset,
      required String toAddress,
      required String amount,
    });

/// 钱包转账服务。
///
/// 该服务负责把用户输入的转账信息转换成各链可广播的交易：
/// - EVM 链：构造 legacy 或 EIP-1559 typed transaction 并用 secp256k1 签名；
/// - TRON：先由节点创建交易，再对 raw_data 做 secp256k1 签名并广播；
/// - Solana：使用 solana Dart 包构造 Message，并用 Ed25519 私钥签名发送。
/// - Bitcoin：查询 UTXO，构造 BIP143 P2WPKH 交易并通过 Esplora 广播。
/// - Sui：解析 Coin Object，构造 PTB，并用 Ed25519 私钥签名广播。
///
/// 这里不负责读取私钥和密码校验。调用方需要先从 [WalletRepository] 读取对应私钥，
/// 再把私钥传入 [transfer]。
class WalletTransferService {
  /// 创建转账服务。
  ///
  /// 测试时可注入 [Dio]；业务场景使用独立 Dio，避免受业务接口 baseUrl 或拦截器影响。
  WalletTransferService({
    Dio? dio,
    this.simulateEvmTransactions = true,
    ChainAdapterRegistry? adapterRegistry,
    Map<String, ChainTransferOperation> transferOperations = const {},
    Map<String, ChainFeeEstimator> feeEstimators = const {},
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: _requestTimeout,
               receiveTimeout: _requestTimeout,
               sendTimeout: _requestTimeout,
             ),
           ),
       _domain = ECCurve_secp256k1(),
       _adapterRegistry = adapterRegistry ?? _createAdapterRegistry() {
    _transferOperations = ChainOperationRegistry({
      WalletAddressNamespace.evm: _transferEvmOperation,
      WalletAddressNamespace.tron: _transferTronOperation,
      WalletAddressNamespace.solana: _transferSolanaOperation,
      WalletAddressNamespace.bitcoin: _transferBitcoinOperation,
      WalletAddressNamespace.sui: _transferSuiOperation,
      WalletAddressNamespace.aptos: _transferAptosOperation,
      ...transferOperations,
    });
    _feeEstimators = ChainOperationRegistry({
      WalletAddressNamespace.evm: _estimateEvmFee,
      WalletAddressNamespace.tron: _estimateTronFee,
      WalletAddressNamespace.solana: _estimateSolanaFee,
      WalletAddressNamespace.bitcoin: _estimateBitcoinFee,
      WalletAddressNamespace.sui: _estimateSuiFee,
      WalletAddressNamespace.aptos: _estimateAptosFee,
      ...feeEstimators,
    });
  }

  /// RPC/HTTP 请求客户端。
  final Dio _dio;

  /// 是否在 EVM 签名前用完全相同的草稿执行 `eth_call` 模拟。
  final bool simulateEvmTransactions;

  /// secp256k1 曲线参数，EVM 和 TRON 签名共用。
  final ECDomainParameters _domain;

  final ChainAdapterRegistry _adapterRegistry;
  late final ChainOperationRegistry<ChainTransferOperation> _transferOperations;
  late final ChainOperationRegistry<ChainFeeEstimator> _feeEstimators;

  /// 转账相关请求的整体超时时间。
  static const Duration _requestTimeout = Duration(seconds: 20);

  /// 使用共享的加密常量
  static const int _evmNativeGasLimit = CryptoConstants.evmNativeGasLimit;
  static const int _evmTokenGasLimit = CryptoConstants.evmTokenGasLimit;
  static const int _tronTokenFeeLimit = CryptoConstants.tronTokenFeeLimit;
  static const int _solanaLamportsPerSignature =
      CryptoConstants.solanaLamportsPerSignature;
  static final BigInt _secp256k1P = CryptoConstants.secp256k1P;

  /// 发起转账。
  ///
  /// [asset] 决定链类型、资产精度、合约地址和发送方地址；[amount] 是用户输入的人类
  /// 可读数量，会按 decimals 转成链上最小单位。Solana 必须额外传入 Ed25519 私钥 seed。
  Future<String> transfer({
    String? privateKeyHex,
    WalletKeyMaterial? keyMaterial,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
    List<int>? solanaPrivateKey,
    List<int>? suiPrivateKey,
    List<int>? aptosPrivateKey,
    EvmTransactionDraft? evmDraft,
  }) {
    final resolvedPrivateKey =
        keyMaterial?.privateKeyHex ?? privateKeyHex?.trim() ?? '';
    if (resolvedPrivateKey.isEmpty) {
      throw StateError('Missing private key material');
    }
    final adapter = _adapterRegistry.require(
      asset.chainRef,
      capability: ChainCapability.transfer,
    );
    final legacySigningKeys = <String, List<int>>{
      if (solanaPrivateKey != null)
        WalletAddressNamespace.solana: solanaPrivateKey,
      if (suiPrivateKey != null) WalletAddressNamespace.sui: suiPrivateKey,
      if (aptosPrivateKey != null)
        WalletAddressNamespace.aptos: aptosPrivateKey,
    };
    final operation = _transferOperations.require(
      asset.chainRef,
      _adapterRegistry,
      capability: ChainCapability.transfer,
    );
    return operation(
      ChainTransferRequest(
        privateKeyHex: resolvedPrivateKey,
        signingKeyBytes:
            keyMaterial?.signingKeyBytes ??
            legacySigningKeys[adapter.keyMaterialNamespace],
        asset: asset,
        toAddress: toAddress,
        amount: amount,
        evmDraft: evmDraft,
      ),
    );
  }

  /// 实时估算转账手续费。
  ///
  /// 返回值使用链原生币作为手续费单位，例如 EVM 链返回 BNB/ETH/OKB，TRON 返回 TRX，
  /// Solana 返回 SOL。估算失败时部分链会返回 fallback 标记。
  Future<TransferFeeEstimate> estimateFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) {
    final estimator = _feeEstimators.require(
      asset.chainRef,
      _adapterRegistry,
      capability: ChainCapability.feeEstimation,
    );
    return estimator(asset: asset, toAddress: toAddress, amount: amount);
  }

  Future<String> _transferEvmOperation(ChainTransferRequest request) =>
      _transferEvm(
        privateKeyHex: request.privateKeyHex,
        asset: request.asset,
        toAddress: request.toAddress,
        amount: request.amount,
        draft: request.evmDraft,
      );

  Future<String> _transferTronOperation(ChainTransferRequest request) =>
      _transferTron(
        privateKeyHex: request.privateKeyHex,
        asset: request.asset,
        toAddress: request.toAddress,
        amount: request.amount,
      );

  Future<String> _transferSolanaOperation(ChainTransferRequest request) {
    final key = request.signingKeyBytes;
    if (key == null) throw StateError('Missing Solana private key');
    return _transferSolana(
      solanaPrivateKey: key,
      asset: request.asset,
      toAddress: request.toAddress,
      amount: request.amount,
    );
  }

  Future<String> _transferBitcoinOperation(ChainTransferRequest request) =>
      _transferBitcoin(
        privateKeyHex: request.privateKeyHex,
        asset: request.asset,
        toAddress: request.toAddress,
        amount: request.amount,
      );

  Future<String> _transferSuiOperation(ChainTransferRequest request) {
    final key = request.signingKeyBytes;
    if (key == null) throw StateError('Missing Sui private key');
    return _transferSui(
      suiPrivateKey: key,
      asset: request.asset,
      toAddress: request.toAddress,
      amount: request.amount,
    );
  }

  Future<String> _transferAptosOperation(ChainTransferRequest request) {
    final key = request.signingKeyBytes;
    if (key == null) throw StateError('Missing Aptos private key');
    return _transferAptos(
      aptosPrivateKey: key,
      asset: request.asset,
      toAddress: request.toAddress,
      amount: request.amount,
    );
  }

  static ChainAdapterRegistry _createAdapterRegistry() {
    return ChainAdapterRegistry.standard(
      ChainAddressNormalizers(
        evm: normalizeEvmAddress,
        tron: (input) {
          tronAddressToHex(input);
          return input.trim();
        },
        solana: normalizeSolanaAddress,
        bitcoin: normalizeBitcoinAddress,
        sui: normalizeSuiAddress,
        aptos: normalizeAptosAddress,
      ),
    );
  }

  /// 估算 EVM 转账手续费。
  ///
  /// 优先调用 `eth_estimateGas`，失败时使用固定兜底 gasLimit。手续费计算公式为
  /// `gasLimit * gasPrice`，最终按 18 位精度转为链原生币数量。
  ECSignature _signHash(String privateKeyHex, Uint8List hash) {
    final privateKey = BigInt.parse(
      privateKeyHex.replaceFirst(RegExp('^0x'), ''),
      radix: 16,
    );
    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    signer.init(
      true,
      PrivateKeyParameter<ECPrivateKey>(ECPrivateKey(privateKey, _domain)),
    );
    return (signer.generateSignature(hash) as ECSignature).normalize(_domain);
  }

  /// 查找 ECDSA recovery id。
  ///
  /// EVM 和 TRON 都需要 recovery id。这里尝试 0..3，恢复公钥后和私钥推导出的公钥
  /// 做字节比较，匹配的 index 即 recovery id。
  int _findRecoveryId(
    String privateKeyHex,
    Uint8List hash,
    ECSignature signature,
  ) {
    final privateKey = BigInt.parse(
      privateKeyHex.replaceFirst(RegExp('^0x'), ''),
      radix: 16,
    );
    final publicKey = (_domain.G * privateKey)!;
    final publicKeyBytes = publicKey.getEncoded(false);
    for (var i = 0; i < 4; i++) {
      final recovered = _recoverPublicKey(i, signature, hash);
      if (recovered != null &&
          _bytesEqual(recovered.getEncoded(false), publicKeyBytes)) {
        return i;
      }
    }
    throw StateError('Failed to recover signature id');
  }

  /// 根据签名和 recovery id 恢复 secp256k1 公钥。
  ///
  /// 实现标准 ECDSA 公钥恢复公式，用于从签名中验证 recovery id 是否正确。
  ECPoint? _recoverPublicKey(
    int recoveryId,
    ECSignature signature,
    Uint8List hash,
  ) {
    final n = _domain.n;
    final i = BigInt.from(recoveryId ~/ 2);
    final x = signature.r + i * n;
    if (x >= _secp256k1P) return null;

    final r = _domain.curve.decompressPoint(recoveryId & 1, x);
    if (!(r * n)!.isInfinity) return null;

    final e = _bytesToBigInt(hash);
    final eInv = (BigInt.zero - e) % n;
    final rInv = signature.r.modInverse(n);
    final srInv = (signature.s * rInv) % n;
    final eInvRInv = (eInv * rInv) % n;
    return (_domain.G * eInvRInv)! + (r * srInv);
  }

  /// 将用户输入金额转换为链上最小单位整数。
  ///
  /// 例如 1.23 USDT（6 decimals）会转成 1230000。输入必须大于 0，且小数位不能
  /// 超过资产 decimals。
  static BigInt amountToRawUnits(String amount, int decimals) {
    final normalized = amount.trim();
    final value = Decimal.tryParse(normalized);
    if (value == null || value <= Decimal.zero) {
      throw const FormatException('Invalid transfer amount');
    }
    final shifted = value.shift(decimals);
    if (!shifted.isInteger) {
      throw const FormatException('Too many decimal places');
    }
    return shifted.toBigInt();
  }

  /// 将链上最小单位整数格式化为人类可读数量。
  ///
  /// 展示时最多保留 8 位小数，避免手续费或余额文本过长。
  static String rawUnitsToAmount(BigInt value, int decimals) {
    final base = BigInt.from(10).pow(decimals);
    final whole = value ~/ base;
    final fraction = value.remainder(base).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.isEmpty) {
      return whole.toString();
    }
    final displayFraction = trimmed.length > 8
        ? trimmed.substring(0, 8)
        : trimmed;
    return '$whole.$displayFraction';
  }

  /// 将整数编码成 JSON-RPC hex quantity。
  static String _hexQuantity(BigInt value) {
    return '0x${value.toRadixString(16)}';
  }

  /// 编码 ERC20 `transfer(address,uint256)` calldata。
  ///
  /// `0xa9059cbb` 是 transfer 的方法选择器，后面依次拼接 32 字节地址和 32 字节金额。
  static String erc20TransferData(String toAddress, BigInt amount) {
    final address = normalizeEvmAddress(toAddress);
    return '0xa9059cbb'
        '000000000000000000000000${address.replaceFirst('0x', '')}'
        '${amount.toRadixString(16).padLeft(64, '0')}';
  }

  /// 编码 TRC20 transfer 参数。
  ///
  /// TRON 节点的 `triggersmartcontract` 已单独传入 function_selector，这里只返回
  /// ABI 参数部分。
  static String trc20TransferParameter(String toAddress, BigInt amount) {
    final tronHex = tronAddressToHex(toAddress);
    return '000000000000000000000000${tronHex.substring(2)}'
        '${amount.toRadixString(16).padLeft(64, '0')}';
  }

  /// 兼容旧命名的 BSC 地址标准化方法。
  static String normalizeBscAddress(String input) {
    return normalizeEvmAddress(input);
  }

  /// 校验并标准化 EVM 地址。
  ///
  /// 验证 EIP-55 校验和（如果地址包含混合大小写），防止发送到损坏的地址。
  /// 返回小写 `0x` 地址。
  static String normalizeEvmAddress(String input) {
    final address = input.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
      throw const FormatException('Invalid EVM address format');
    }

    // 验证 EIP-55 校验和
    final addr = address.substring(2);

    // 如果地址是混合大小写，验证校验和
    if (addr != addr.toLowerCase() && addr != addr.toUpperCase()) {
      final digest = KeccakDigest(256);
      final hash = digest.process(
        Uint8List.fromList(addr.toLowerCase().codeUnits),
      );
      final hashHex = hex.encode(hash);

      for (int i = 0; i < 40; i++) {
        final hashChar = int.parse(hashHex[i], radix: 16);
        if (hashChar >= 8) {
          if (addr[i] != addr[i].toUpperCase()) {
            throw const FormatException(
              'Invalid EIP-55 checksum: address may be corrupted',
            );
          }
        } else {
          if (addr[i] != addr[i].toLowerCase()) {
            throw const FormatException(
              'Invalid EIP-55 checksum: address may be corrupted',
            );
          }
        }
      }
    }

    return '0x${addr.toLowerCase()}';
  }

  /// 将 TRON Base58Check 地址转为十六进制 payload。
  ///
  /// 有效 TRON 地址 payload 长度为 21 字节，首字节固定为 `0x41`。
  static String tronAddressToHex(String address) {
    final payload = _base58CheckDecode(address.trim());
    if (payload.length != 21 || payload.first != 0x41) {
      throw const FormatException('Invalid TRON address');
    }
    return hex.encode(payload);
  }

  /// 校验并标准化 Solana 地址。
  ///
  /// Solana 地址必须能 Base58 解码为 32 字节公钥。返回值保留原始文本。
  static String normalizeSolanaAddress(String input) {
    final address = input.trim();
    final decoded = _base58Decode(address);
    if (decoded.length != 32) {
      throw const FormatException('Invalid Solana address');
    }
    return address;
  }

  /// 校验并标准化 Sui 32 字节十六进制地址。
  static String normalizeSuiAddress(String input) {
    final address = input.trim().toLowerCase();
    if (!SuiAccount.isValidAddress(address)) {
      throw const FormatException('Invalid Sui address');
    }
    return address;
  }

  static String normalizeAptosAddress(String input) {
    final value = input.trim().toLowerCase();
    final hexValue = value.startsWith('0x') ? value.substring(2) : value;
    if (hexValue.isEmpty ||
        hexValue.length > 64 ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(hexValue)) {
      throw const FormatException('Invalid Aptos address');
    }
    return '0x${hexValue.padLeft(64, '0')}';
  }

  /// 校验 Bitcoin Mainnet BIP84 P2WPKH 地址并统一为小写。
  ///
  /// 首版仅接受 witness version 0、20 字节 witness program 的 `bc1q...` 地址。
  static String normalizeBitcoinAddress(String input) {
    final original = input.trim();
    if (original.isEmpty ||
        (original != original.toLowerCase() &&
            original != original.toUpperCase())) {
      throw const FormatException('Invalid Bitcoin address casing');
    }
    final address = original.toLowerCase();
    final separator = address.lastIndexOf('1');
    if (separator <= 0 || separator + 7 > address.length) {
      throw const FormatException('Invalid Bitcoin address format');
    }
    if (address.substring(0, separator) != 'bc') {
      throw const FormatException('Bitcoin mainnet address required');
    }
    final data = <int>[];
    for (final codeUnit in address.substring(separator + 1).codeUnits) {
      final value = CryptoConstants.bech32Alphabet.indexOf(
        String.fromCharCode(codeUnit),
      );
      if (value < 0) {
        throw const FormatException('Invalid Bitcoin address character');
      }
      data.add(value);
    }
    if (!_verifyBech32Checksum('bc', data)) {
      throw const FormatException('Invalid Bitcoin address checksum');
    }
    final payload = data.sublist(0, data.length - 6);
    if (payload.isEmpty || payload.first != 0) {
      throw const FormatException('Only Bitcoin P2WPKH is supported');
    }
    final program = _convertBitcoinBits(
      payload.sublist(1),
      fromBits: 5,
      toBits: 8,
      pad: false,
    );
    if (program.length != 20) {
      throw const FormatException('Only Bitcoin P2WPKH is supported');
    }
    return address;
  }

  static bool _verifyBech32Checksum(String hrp, List<int> data) {
    final expanded = <int>[
      ...hrp.codeUnits.map((value) => value >> 5),
      0,
      ...hrp.codeUnits.map((value) => value & 31),
      ...data,
    ];
    var polymod = 1;
    const generators = [
      0x3b6a57b2,
      0x26508e6d,
      0x1ea119fa,
      0x3d4233dd,
      0x2a1462b3,
    ];
    for (final value in expanded) {
      final top = polymod >> 25;
      polymod = ((polymod & 0x1ffffff) << 5) ^ value;
      for (var i = 0; i < generators.length; i++) {
        if (((top >> i) & 1) != 0) polymod ^= generators[i];
      }
    }
    return polymod == 1;
  }

  static Uint8List _convertBitcoinBits(
    List<int> data, {
    required int fromBits,
    required int toBits,
    required bool pad,
  }) {
    var accumulator = 0;
    var bitCount = 0;
    final result = <int>[];
    final maxValue = (1 << toBits) - 1;
    final maxAccumulator = (1 << (fromBits + toBits - 1)) - 1;
    for (final value in data) {
      if (value < 0 || (value >> fromBits) != 0) {
        throw const FormatException('Invalid Bitcoin address data');
      }
      accumulator = ((accumulator << fromBits) | value) & maxAccumulator;
      bitCount += fromBits;
      while (bitCount >= toBits) {
        bitCount -= toBits;
        result.add((accumulator >> bitCount) & maxValue);
      }
    }
    if (pad) {
      if (bitCount > 0) {
        result.add((accumulator << (toBits - bitCount)) & maxValue);
      }
    } else if (bitCount >= fromBits ||
        ((accumulator << (toBits - bitCount)) & maxValue) != 0) {
      throw const FormatException('Invalid Bitcoin address padding');
    }
    return Uint8List.fromList(result);
  }

  /// 将 Solana 转账金额转为 u64 可接受的 int。
  ///
  /// solana Dart 指令 API 使用 int，超出安全范围或非正数时直接拒绝。
  static int _solanaU64Amount(BigInt value, String label) {
    final maxSignedInt64 = (BigInt.one << 63) - BigInt.one;
    if (value <= BigInt.zero || value > maxSignedInt64) {
      throw FormatException('Invalid $label');
    }
    return value.toInt();
  }

  /// 将十六进制字符串转为字节数组。
  static Uint8List hexToBytes(String value) {
    return Uint8List.fromList(hex.decode(value.replaceFirst('0x', '')));
  }

  /// RLP 编码入口。
  ///
  /// EVM legacy 和 EIP-1559 transaction 使用 RLP 编码。这里支持 BigInt、int、
  /// Uint8List、List<int> 和嵌套 List。
  static Uint8List _rlpEncode(dynamic value) {
    if (value is BigInt) {
      if (value == BigInt.zero) {
        return _rlpEncodeBytes(Uint8List(0));
      }
      return _rlpEncodeBytes(_bigIntToBytes(value));
    }
    if (value is int) {
      return _rlpEncode(BigInt.from(value));
    }
    if (value is Uint8List) {
      return _rlpEncodeBytes(value);
    }
    if (value is List<int>) {
      return _rlpEncodeBytes(Uint8List.fromList(value));
    }
    if (value is List) {
      final payload = Uint8List.fromList(value.expand(_rlpEncode).toList());
      if (payload.length < 56) {
        return Uint8List.fromList([0xc0 + payload.length, ...payload]);
      }
      final lengthBytes = _bigIntToBytes(BigInt.from(payload.length));
      return Uint8List.fromList([
        0xf7 + lengthBytes.length,
        ...lengthBytes,
        ...payload,
      ]);
    }
    throw ArgumentError('Unsupported RLP value');
  }

  /// RLP 字节串编码。
  static Uint8List _rlpEncodeBytes(Uint8List bytes) {
    if (bytes.length == 1 && bytes.first < 0x80) {
      return bytes;
    }
    if (bytes.length < 56) {
      return Uint8List.fromList([0x80 + bytes.length, ...bytes]);
    }
    final lengthBytes = _bigIntToBytes(BigInt.from(bytes.length));
    return Uint8List.fromList([
      0xb7 + lengthBytes.length,
      ...lengthBytes,
      ...bytes,
    ]);
  }

  /// Keccak-256 哈希。
  static Uint8List _keccak(Uint8List input) {
    final digest = KeccakDigest(256)..update(input, 0, input.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output;
  }

  /// SHA-256 哈希。
  static Uint8List _sha256(Uint8List input) {
    final digest = SHA256Digest()..update(input, 0, input.length);
    final output = Uint8List(32);
    digest.doFinal(output, 0);
    return output;
  }

  /// Base58Check 解码并校验 checksum。
  ///
  /// TRON 地址使用双 SHA-256 前 4 字节作为校验和。
  static Uint8List _base58CheckDecode(String input) {
    final decoded = _base58Decode(input);
    if (decoded.length < 5) {
      throw const FormatException('Invalid Base58Check payload');
    }
    final payload = decoded.sublist(0, decoded.length - 4);
    final checksum = decoded.sublist(decoded.length - 4);
    final expected = _sha256(_sha256(payload)).sublist(0, 4);
    if (!_bytesEqual(checksum, expected)) {
      throw const FormatException('Invalid Base58Check checksum');
    }
    return payload;
  }

  /// Base58 解码。
  ///
  /// 解码时需要恢复开头的 `1` 对应的 0 字节。
  static Uint8List _base58Decode(String input) {
    var value = BigInt.zero;
    for (final codeUnit in input.codeUnits) {
      final digit = CryptoConstants.base58Alphabet.indexOf(
        String.fromCharCode(codeUnit),
      );
      if (digit < 0) {
        throw const FormatException('Invalid Base58 character');
      }
      value = value * BigInt.from(58) + BigInt.from(digit);
    }

    final bytes = _bigIntToBytes(value).toList();
    var leadingZeros = 0;
    for (final codeUnit in input.codeUnits) {
      if (String.fromCharCode(codeUnit) == CryptoConstants.base58Alphabet[0]) {
        leadingZeros++;
      } else {
        break;
      }
    }
    return Uint8List.fromList([...List<int>.filled(leadingZeros, 0), ...bytes]);
  }

  /// 将整数转为大端字节数组。
  ///
  /// [length] 不为空时会左侧补 0 到固定长度，并在数值放不下时抛错。
  static Uint8List _bigIntToBytes(BigInt value, {int? length}) {
    if (value == BigInt.zero) {
      return Uint8List(length ?? 0);
    }
    final bytes = <int>[];
    var current = value;
    while (current > BigInt.zero) {
      bytes.add((current & BigInt.from(0xff)).toInt());
      current >>= 8;
    }
    final result = bytes.reversed.toList();
    if (length != null) {
      if (result.length > length) {
        throw ArgumentError('BigInt does not fit in $length bytes');
      }
      return Uint8List.fromList([
        ...List<int>.filled(length - result.length, 0),
        ...result,
      ]);
    }
    return Uint8List.fromList(result);
  }

  /// 将大端字节数组转为整数。
  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  /// 常量时间风格的字节数组比较。
  ///
  /// 用于签名恢复时比较公钥字节，避免提前返回带来的分支差异。
  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// 转账手续费估算结果。
class TransferFeeEstimate {
  const TransferFeeEstimate({
    required this.amount,
    required this.symbol,
    required this.rawAmount,
    this.isFallback = false,
    this.evmDraft,
  });

  /// 人类可读手续费数量。
  final String amount;

  /// 手续费单位，一般是链原生币符号。
  final String symbol;

  /// 手续费最小单位数量。
  final BigInt rawAmount;

  /// true 表示使用兜底估算值，而不是节点实时估算结果。
  final bool isFallback;

  /// EVM 费用估算对应的完整交易草稿；非 EVM 链为 null。
  final EvmTransactionDraft? evmDraft;

  /// UI 展示文案。
  String get displayText => '$amount $symbol';
}
