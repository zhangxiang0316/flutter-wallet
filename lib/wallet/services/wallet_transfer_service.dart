import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/digests/keccak.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256k1.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
import 'package:solana/solana.dart';

import '../constants/crypto_constants.dart';
import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_chain_extensions.dart';

part 'transfer/evm_wallet_transfer.dart';
part 'transfer/tron_wallet_transfer.dart';
part 'transfer/solana_wallet_transfer.dart';

/// 钱包转账服务。
///
/// 该服务负责把用户输入的转账信息转换成各链可广播的交易：
/// - EVM 链：构造 legacy transaction，RLP 编码后用 secp256k1 私钥签名；
/// - TRON：先由节点创建交易，再对 raw_data 做 secp256k1 签名并广播；
/// - Solana：使用 solana Dart 包构造 Message，并用 Ed25519 私钥签名发送。
///
/// 这里不负责读取私钥和密码校验。调用方需要先从 [WalletRepository] 读取对应私钥，
/// 再把私钥传入 [transfer]。
class WalletTransferService {
  /// 创建转账服务。
  ///
  /// 测试时可注入 [Dio]；业务场景使用独立 Dio，避免受业务接口 baseUrl 或拦截器影响。
  WalletTransferService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          ),
      _domain = ECCurve_secp256k1();

  /// RPC/HTTP 请求客户端。
  final Dio _dio;

  /// secp256k1 曲线参数，EVM 和 TRON 签名共用。
  final ECDomainParameters _domain;

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
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
    List<int>? solanaPrivateKey,
  }) {
    if (asset.chainRef.isEvm) {
      return _transferEvm(
        privateKeyHex: privateKeyHex,
        asset: asset,
        toAddress: toAddress,
        amount: amount,
      );
    }
    if (asset.chainRef.isTron) {
      return _transferTron(
        privateKeyHex: privateKeyHex,
        asset: asset,
        toAddress: toAddress,
        amount: amount,
      );
    }
    if (asset.chainRef.isSolana) {
      if (solanaPrivateKey == null) {
        throw StateError('Missing Solana private key');
      }
      return _transferSolana(
        solanaPrivateKey: solanaPrivateKey,
        asset: asset,
        toAddress: toAddress,
        amount: amount,
      );
    }
    throw StateError('Unsupported chain ${asset.chainId}');
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
    if (asset.chainRef.isEvm) {
      return _estimateEvmFee(
        asset: asset,
        toAddress: toAddress,
        amount: amount,
      );
    }
    if (asset.chainRef.isTron) {
      return _estimateTronFee(
        asset: asset,
        toAddress: toAddress,
        amount: amount,
      );
    }
    if (asset.chainRef.isSolana) {
      return _estimateSolanaFee(
        asset: asset,
        toAddress: toAddress,
        amount: amount,
      );
    }
    throw StateError('Unsupported chain ${asset.chainId}');
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

  /// 将 Solana 转账金额转为 u64 可接受的 int。
  ///
  /// solana Dart 指令 API 使用 int，超出安全范围或非正数时直接拒绝。
  static int _solanaU64Amount(BigInt value, String label) {
    if (value <= BigInt.zero || value > BigInt.from(0x7fffffffffffffff)) {
      throw FormatException('Invalid $label');
    }
    return value.toInt();
  }

  /// 将十六进制字符串转为字节数组。
  static Uint8List hexToBytes(String value) {
    return Uint8List.fromList(hex.decode(value.replaceFirst('0x', '')));
  }

  // ========== 消息签名方法（Phase 2 新增）==========

  /// EIP-191 personal_sign 签名
  ///
  /// 对消息添加 Ethereum 前缀后签名：
  /// "\x19Ethereum Signed Message:\n" + len(message) + message
  ///
  /// 返回十六进制签名字符串（带 0x 前缀）
  Future<String> signPersonalMessage({
    required String message,
    required String privateKeyHex,
  }) async {
    // 1. 构造带前缀的消息
    final messageBytes = _isHexString(message)
        ? hexToBytes(message)
        : Uint8List.fromList(message.codeUnits);

    final prefix = '\x19Ethereum Signed Message:\n${messageBytes.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);

    final fullMessage = Uint8List.fromList([...prefixBytes, ...messageBytes]);

    // 2. Keccak-256 哈希
    final hash = _keccak(fullMessage);

    // 3. 使用 secp256k1 签名
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);

    // 4. 组装签名：r + s + v
    final rBytes = _bigIntToBytes(signature.r, length: 32);
    final sBytes = _bigIntToBytes(signature.s, length: 32);

    // 5. 返回十六进制签名
    return '0x${hex.encode([...rBytes, ...sBytes, recoveryId])}';
  }

  /// EIP-712 typed data 签名
  ///
  /// 对结构化数据进行签名，用于更复杂的授权场景。
  /// typedData 格式参考 EIP-712 规范。
  ///
  /// 返回十六进制签名字符串（带 0x 前缀）
  Future<String> signTypedData({
    required Map<String, dynamic> typedData,
    required String privateKeyHex,
  }) async {
    // 1. 计算 EIP-712 domain separator
    final domainSeparator = _hashStruct(
      typedData['domain'] as Map<String, dynamic>,
      typedData['types'] as Map<String, dynamic>,
      'EIP712Domain',
    );

    // 2. 计算消息哈希
    final messageHash = _hashStruct(
      typedData['message'] as Map<String, dynamic>,
      typedData['types'] as Map<String, dynamic>,
      typedData['primaryType'] as String,
    );

    // 3. 构造 EIP-712 签名数据
    // "\x19\x01" + domainSeparator + messageHash
    final signData = Uint8List.fromList([
      0x19,
      0x01,
      ...domainSeparator,
      ...messageHash,
    ]);

    // 4. Keccak-256 哈希
    final hash = _keccak(signData);

    // 5. 使用 secp256k1 签名
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);

    // 6. 组装签名
    final rBytes = _bigIntToBytes(signature.r, length: 32);
    final sBytes = _bigIntToBytes(signature.s, length: 32);

    // 7. 返回十六进制签名
    return '0x${hex.encode([...rBytes, ...sBytes, recoveryId])}';
  }

  /// Solana 消息签名
  ///
  /// 使用 Ed25519 签名原始消息或 UTF-8 文本。
  ///
  /// 返回 Base58 编码的签名字符串
  Future<String> signSolanaMessage({
    required String message,
    required Uint8List privateKeySeed,
  }) async {
    // 1. 将消息转为字节
    final messageBytes = _isHexString(message)
        ? hexToBytes(message)
        : Uint8List.fromList(message.codeUnits);

    // 2. 从 seed 生成 Ed25519 keypair
    final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: privateKeySeed,
    );

    // 3. 签名消息
    final signature = await keypair.sign(messageBytes);

    // 4. 返回 Base58 编码的签名
    return signature.toBase58();
  }

  /// TRON 消息签名
  ///
  /// 使用与 TRON 交易相同的 secp256k1 签名，
  /// 但对原始消息进行 SHA-256 哈希（而非交易的 raw_data）。
  ///
  /// 返回十六进制签名字符串（带 0x 前缀）
  Future<String> signTronMessage({
    required String message,
    required String privateKeyHex,
  }) async {
    // 1. 添加 TRON 消息前缀
    final messageBytes = _isHexString(message)
        ? hexToBytes(message)
        : Uint8List.fromList(message.codeUnits);

    final prefix = '\x19TRON Signed Message:\n${messageBytes.length}';
    final prefixBytes = Uint8List.fromList(prefix.codeUnits);

    final fullMessage = Uint8List.fromList([...prefixBytes, ...messageBytes]);

    // 2. SHA-256 哈希（TRON 使用 SHA-256，不是 Keccak-256）
    final digest = SHA256Digest();
    final hash = digest.process(fullMessage);

    // 3. 使用 secp256k1 签名
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);

    // 4. 组装签名
    final rBytes = _bigIntToBytes(signature.r, length: 32);
    final sBytes = _bigIntToBytes(signature.s, length: 32);

    // 5. 返回十六进制签名
    return '0x${hex.encode([...rBytes, ...sBytes, recoveryId])}';
  }

  // ========== EIP-712 辅助方法 ==========

  /// 判断字符串是否为十六进制格式
  bool _isHexString(String value) {
    return value.startsWith('0x') || RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }

  /// EIP-712 结构体哈希
  Uint8List _hashStruct(
    Map<String, dynamic> data,
    Map<String, dynamic> types,
    String typeName,
  ) {
    // 获取类型定义
    final type = types[typeName] as List<dynamic>;

    // 1. 计算 typeHash
    final encodeType = _encodeType(typeName, types);
    final typeHash = _keccak(Uint8List.fromList(encodeType.codeUnits));

    // 2. 编码每个字段
    final encodedValues = <int>[...typeHash];
    for (final field in type) {
      final fieldName = field['name'] as String;
      final fieldType = field['type'] as String;
      final fieldValue = data[fieldName];

      encodedValues.addAll(_encodeValue(fieldType, fieldValue, types));
    }

    // 3. Keccak-256 哈希
    return _keccak(Uint8List.fromList(encodedValues));
  }

  /// EIP-712 类型编码
  String _encodeType(String typeName, Map<String, dynamic> types) {
    final type = types[typeName] as List<dynamic>;
    final fields = type.map((f) => '${f['type']} ${f['name']}').join(',');
    return '$typeName($fields)';
  }

  /// EIP-712 值编码
  Uint8List _encodeValue(
    String type,
    dynamic value,
    Map<String, dynamic> types,
  ) {
    // 基础类型
    if (type == 'address') {
      final addr = (value as String).replaceFirst('0x', '').padLeft(64, '0');
      return hexToBytes('0x$addr');
    }
    if (type == 'string') {
      return _keccak(Uint8List.fromList((value as String).codeUnits));
    }
    if (type == 'bytes') {
      return _keccak(hexToBytes(value as String));
    }
    if (type.startsWith('uint') || type.startsWith('int')) {
      final numValue = BigInt.parse(value.toString());
      return _bigIntToBytes(numValue, length: 32);
    }
    if (type == 'bool') {
      return _bigIntToBytes(
        value == true ? BigInt.one : BigInt.zero,
        length: 32,
      );
    }

    // 自定义结构体
    if (types.containsKey(type)) {
      return _hashStruct(value as Map<String, dynamic>, types, type);
    }

    // 数组类型
    if (type.endsWith('[]')) {
      final itemType = type.substring(0, type.length - 2);
      final items = (value as List)
          .map((item) => _encodeValue(itemType, item, types))
          .toList();
      final concatenated = items.expand((x) => x).toList();
      return _keccak(Uint8List.fromList(concatenated));
    }

    throw ArgumentError('Unsupported type: $type');
  }

  /// RLP 编码入口。
  ///
  /// EVM legacy transaction 使用 RLP 编码。这里支持本文件需要的 BigInt、int、
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
  });

  /// 人类可读手续费数量。
  final String amount;

  /// 手续费单位，一般是链原生币符号。
  final String symbol;

  /// 手续费最小单位数量。
  final BigInt rawAmount;

  /// true 表示使用兜底估算值，而不是节点实时估算结果。
  final bool isFallback;

  /// UI 展示文案。
  String get displayText => '$amount $symbol';
}
