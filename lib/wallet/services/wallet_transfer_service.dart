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
  static const int _solanaLamportsPerSignature = CryptoConstants.solanaLamportsPerSignature;
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
  Future<TransferFeeEstimate> _estimateEvmFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final normalizedTo = normalizeEvmAddress(toAddress);
    final value = amountToRawUnits(amount, asset.decimals);
    final isNative = asset.isNative;
    final txTo = isNative ? normalizedTo : asset.contractAddress!;
    final txValue = isNative ? value : BigInt.zero;
    final data = isNative ? '0x' : erc20TransferData(normalizedTo, value);
    final gasPrice = await _evmRpcBigInt(
      asset.chainRef,
      'eth_gasPrice',
      const [],
    );
    BigInt gasLimit;
    try {
      gasLimit = await _evmRpcBigInt(asset.chainRef, 'eth_estimateGas', [
        {
          'from': asset.address,
          'to': txTo,
          'value': _hexQuantity(txValue),
          if (!isNative) 'data': data,
        },
      ]);
    } catch (_) {
      gasLimit = BigInt.from(isNative ? _evmNativeGasLimit : _evmTokenGasLimit);
    }

    final feeWei = gasLimit * gasPrice;
    return TransferFeeEstimate(
      amount: rawUnitsToAmount(feeWei, 18),
      symbol: asset.chainRef.symbol,
      rawAmount: feeWei,
      isFallback: false,
    );
  }

  /// 估算 TRON 转账手续费。
  ///
  /// TRX 原生转账主要消耗带宽，TRC20 转账还需要能量。这里会读取链参数里的
  /// `getTransactionFee` 和 `getEnergyFee`，再按交易字节数和能量估算 sun。
  Future<TransferFeeEstimate> _estimateTronFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final value = amountToRawUnits(amount, asset.decimals);
    final chainParameters = await _loadTronChainParameters(asset.chainRef);
    final transactionFee = chainParameters['getTransactionFee'] ?? BigInt.one;
    final energyFee = chainParameters['getEnergyFee'] ?? BigInt.from(420);

    if (asset.isNative) {
      final transaction = await _createTronNativeTransaction(
        chain: asset.chainRef,
        fromAddress: asset.address,
        toAddress: toAddress,
        amount: value,
      );
      final rawDataHex = transaction['raw_data_hex']?.toString() ?? '';
      final bandwidthBytes = BigInt.from(rawDataHex.length ~/ 2);
      final feeSun = bandwidthBytes * transactionFee;
      return TransferFeeEstimate(
        amount: rawUnitsToAmount(feeSun, 6),
        symbol: asset.chainRef.symbol,
        rawAmount: feeSun,
        isFallback: false,
      );
    }

    final energy = await _estimateTronEnergy(
      chain: asset.chainRef,
      fromAddress: asset.address,
      toAddress: toAddress,
      contractAddress: asset.contractAddress!,
      amount: value,
    );
    if (energy != null) {
      final transaction = await _createTronTokenTransaction(
        chain: asset.chainRef,
        fromAddress: asset.address,
        toAddress: toAddress,
        contractAddress: asset.contractAddress!,
        amount: value,
      );
      final rawDataHex = transaction['raw_data_hex']?.toString() ?? '';
      final bandwidthFee = BigInt.from(rawDataHex.length ~/ 2) * transactionFee;
      final feeSun = energy * energyFee + bandwidthFee;
      return TransferFeeEstimate(
        amount: rawUnitsToAmount(feeSun, 6),
        symbol: asset.chainRef.symbol,
        rawAmount: feeSun,
        isFallback: false,
      );
    }

    final fallbackFee = BigInt.from(_tronTokenFeeLimit);
    return TransferFeeEstimate(
      amount: rawUnitsToAmount(fallbackFee, 6),
      symbol: asset.chainRef.symbol,
      rawAmount: fallbackFee,
      isFallback: true,
    );
  }

  /// 估算 Solana 转账手续费。
  ///
  /// 当前使用单签名固定费用估算。SPL Token 实际交易会额外包含创建 ATA 的指令，
  /// 这里先返回基础 fallback 费用，避免 UI 阻塞在复杂模拟请求上。
  Future<TransferFeeEstimate> _estimateSolanaFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    normalizeSolanaAddress(toAddress);
    amountToRawUnits(amount, asset.decimals);
    final signatureCount = asset.isNative ? 1 : 1;
    return TransferFeeEstimate(
      amount: rawUnitsToAmount(
        BigInt.from(_solanaLamportsPerSignature * signatureCount),
        9,
      ),
      symbol: asset.chainRef.symbol,
      rawAmount: BigInt.from(_solanaLamportsPerSignature * signatureCount),
      isFallback: true,
    );
  }

  /// 发送 EVM 链交易。
  ///
  /// 原生币交易把金额放在 value；ERC20 交易把 value 设为 0，并把 transfer 调用编码
  /// 放进 data。签名使用 EIP-155 的 chainId 防重放规则。
  Future<String> _transferEvm({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final chainId = asset.chainRef.evmChainId;
    if (chainId == null) {
      throw StateError('${asset.chainRef.name} is not an EVM chain');
    }

    final normalizedTo = normalizeEvmAddress(toAddress);
    final value = amountToRawUnits(amount, asset.decimals);
    final gasPrice = await _evmRpcBigInt(
      asset.chainRef,
      'eth_gasPrice',
      const [],
    );
    final nonce = await _evmRpcBigInt(
      asset.chainRef,
      'eth_getTransactionCount',
      [asset.address, 'latest'],
    );

    final isNative = asset.isNative;
    final txTo = isNative ? normalizedTo : asset.contractAddress!;
    final txValue = isNative ? value : BigInt.zero;
    final data = isNative
        ? Uint8List(0)
        : hexToBytes(erc20TransferData(normalizedTo, value));
    final gasLimit = isNative ? _evmNativeGasLimit : _evmTokenGasLimit;
    final rawTx = _signEvmTransaction(
      privateKeyHex: privateKeyHex,
      nonce: nonce,
      gasPrice: gasPrice,
      gasLimit: BigInt.from(gasLimit),
      toAddress: txTo,
      value: txValue,
      data: data,
      chainId: chainId,
    );
    final response = await _evmRpc(asset.chainRef, 'eth_sendRawTransaction', [
      '0x$rawTx',
    ]);
    if (response is String && response.isNotEmpty) {
      return response;
    }
    throw StateError('${asset.chainRef.name} transfer failed');
  }

  /// 发送 TRON 链交易。
  ///
  /// 先通过节点创建未签名交易，再对 `raw_data_hex` 做 SHA-256 后 secp256k1 签名，
  /// 最后调用 `broadcasttransaction` 广播。
  Future<String> _transferTron({
    required String privateKeyHex,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final value = amountToRawUnits(amount, asset.decimals);
    final transaction = asset.isNative
        ? await _createTronNativeTransaction(
            chain: asset.chainRef,
            fromAddress: asset.address,
            toAddress: toAddress,
            amount: value,
          )
        : await _createTronTokenTransaction(
            chain: asset.chainRef,
            fromAddress: asset.address,
            toAddress: toAddress,
            contractAddress: asset.contractAddress!,
            amount: value,
          );

    final signedTransaction = _signTronTransaction(
      privateKeyHex: privateKeyHex,
      transaction: transaction,
    );
    final response = await _dio.post(
      '${asset.chainRef.rpcUrl}/wallet/broadcasttransaction',
      data: signedTransaction,
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['result'] == true) {
      return data['txid']?.toString() ??
          signedTransaction['txID']?.toString() ??
          '';
    }
    throw StateError(data is Map ? data.toString() : 'TRON transfer failed');
  }

  /// 发送 Solana 交易。
  ///
  /// 先根据私钥恢复 signer，并校验 signer 地址必须等于资产发送方地址，防止拿错钱包
  /// 私钥后签出错误交易。原生 SOL 和 SPL Token 使用不同 message 构造逻辑。
  Future<String> _transferSolana({
    required List<int> solanaPrivateKey,
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final rawAmount = amountToRawUnits(amount, asset.decimals);
    final signer = await Ed25519HDKeyPair.fromPrivateKeyBytes(
      privateKey: solanaPrivateKey,
    );
    if (signer.address != normalizeSolanaAddress(asset.address)) {
      throw StateError('Solana private key does not match sender address');
    }

    final recipientPublicKey = Ed25519HDPublicKey.fromBase58(
      normalizeSolanaAddress(toAddress),
    );
    final blockhash = await _getLatestSolanaBlockhash(asset.chainRef);
    final message = asset.isNative
        ? _buildSolanaNativeTransferMessage(
            fromPublicKey: signer.publicKey,
            toPublicKey: recipientPublicKey,
            lamports: rawAmount,
          )
        : await _buildSolanaTokenTransferMessage(
            chain: asset.chainRef,
            ownerPublicKey: signer.publicKey,
            recipientPublicKey: recipientPublicKey,
            asset: asset,
            amount: rawAmount,
          );
    final transaction = await signer.signMessage(
      message: message,
      recentBlockhash: blockhash,
    );
    final response = await _solanaRpc(asset.chainRef, 'sendTransaction', [
      transaction.encode(),
      {'encoding': 'base64', 'preflightCommitment': 'confirmed'},
    ]);
    if (response is String && response.isNotEmpty) {
      return response;
    }
    throw StateError('Solana transfer failed');
  }

  /// 创建 TRX 原生转账交易。
  ///
  /// 返回的是节点构造好的未签名交易，后续还需要本地签名和广播。
  Future<Map<String, dynamic>> _createTronNativeTransaction({
    required WalletChainRef chain,
    required String fromAddress,
    required String toAddress,
    required BigInt amount,
  }) async {
    final response = await _dio.post(
      '${chain.rpcUrl}/wallet/createtransaction',
      data: {
        'owner_address': fromAddress,
        'to_address': toAddress,
        'amount': amount.toInt(),
        'visible': true,
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['raw_data_hex'] is String) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Invalid TRON transaction response');
  }

  /// 创建 TRC20 转账交易。
  ///
  /// 使用 `triggersmartcontract` 调用 `transfer(address,uint256)`，参数由
  /// [trc20TransferParameter] 按 ABI 格式编码。
  Future<Map<String, dynamic>> _createTronTokenTransaction({
    required WalletChainRef chain,
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amount,
  }) async {
    final response = await _dio.post(
      '${chain.rpcUrl}/wallet/triggersmartcontract',
      data: {
        'owner_address': fromAddress,
        'contract_address': contractAddress,
        'function_selector': 'transfer(address,uint256)',
        'parameter': trc20TransferParameter(toAddress, amount),
        'fee_limit': _tronTokenFeeLimit,
        'call_value': 0,
        'visible': true,
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['transaction'] is Map) {
      return Map<String, dynamic>.from(data['transaction'] as Map);
    }
    throw StateError('Invalid TRC20 transaction response');
  }

  /// 发送 EVM JSON-RPC 请求并返回 result。
  Future<dynamic> _evmRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final response = await _dio.post(
      chain.rpcUrl,
      data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['result'] != null) {
      return data['result'];
    }
    throw StateError(
      data is Map ? data.toString() : 'Invalid ${chain.name} response',
    );
  }

  /// 发送 EVM JSON-RPC 请求并把十六进制数量解析成 [BigInt]。
  Future<BigInt> _evmRpcBigInt(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _evmRpc(chain, method, params);
    if (result is! String) {
      throw StateError('Invalid ${chain.name} number response');
    }
    return BigInt.parse(result.replaceFirst('0x', ''), radix: 16);
  }

  /// 发送 Solana JSON-RPC 请求并返回 result。
  Future<dynamic> _solanaRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final response = await _dio.post(
      chain.rpcUrl,
      data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    if (data is Map && data['result'] != null) {
      return data['result'];
    }
    throw StateError(data is Map ? data.toString() : 'Invalid Solana response');
  }

  /// 获取 Solana 最新 blockhash。
  ///
  /// Solana 交易必须带 recentBlockhash，过期后交易会被节点拒绝。
  Future<String> _getLatestSolanaBlockhash(WalletChainRef chain) async {
    final result = await _solanaRpc(chain, 'getLatestBlockhash', [
      {'commitment': 'confirmed'},
    ]);
    if (result is Map) {
      final value = result['value'];
      if (value is Map && value['blockhash'] is String) {
        return value['blockhash'] as String;
      }
    }
    throw StateError('Invalid Solana blockhash response');
  }

  /// 读取 TRON 链手续费参数。
  ///
  /// 返回 key 为链参数名，value 为链上整数值。请求失败时返回空 map，由调用方使用默认值。
  Future<Map<String, BigInt>> _loadTronChainParameters(
    WalletChainRef chain,
  ) async {
    try {
      final response = await _dio.get(
        '${chain.rpcUrl}/wallet/getchainparameters',
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map || data['chainParameter'] is! List) {
        return {};
      }
      final values = <String, BigInt>{};
      for (final item in data['chainParameter'] as List) {
        if (item is! Map) continue;
        final key = item['key']?.toString();
        final value = BigInt.tryParse(item['value']?.toString() ?? '');
        if (key != null && value != null) {
          values[key] = value;
        }
      }
      return values;
    } catch (_) {
      return {};
    }
  }

  /// 估算 TRC20 转账所需能量。
  ///
  /// 公共节点可能不支持该接口，所以失败时返回 null，并由调用方使用 fee_limit 兜底。
  Future<BigInt?> _estimateTronEnergy({
    required WalletChainRef chain,
    required String fromAddress,
    required String toAddress,
    required String contractAddress,
    required BigInt amount,
  }) async {
    try {
      final response = await _dio.post(
        '${chain.rpcUrl}/wallet/estimateenergy',
        data: {
          'owner_address': fromAddress,
          'contract_address': contractAddress,
          'function_selector': 'transfer(address,uint256)',
          'parameter': trc20TransferParameter(toAddress, amount),
          'visible': true,
        },
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map) return null;
      final value = data['energy_required'] ?? data['energy_used'];
      return BigInt.tryParse(value?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// 签名 EVM legacy transaction。
  ///
  /// 先对包含 chainId 的 payload 做 RLP 编码并 Keccak，然后 ECDSA 签名；最终把
  /// `v/r/s` 回填到交易 payload，返回可直接广播的十六进制裸交易。
  String _signEvmTransaction({
    required String privateKeyHex,
    required BigInt nonce,
    required BigInt gasPrice,
    required BigInt gasLimit,
    required String toAddress,
    required BigInt value,
    required Uint8List data,
    required int chainId,
  }) {
    final toBytes = hexToBytes(normalizeBscAddress(toAddress));
    final signingPayload = _rlpEncode([
      nonce,
      gasPrice,
      gasLimit,
      toBytes,
      value,
      data,
      BigInt.from(chainId),
      BigInt.zero,
      BigInt.zero,
    ]);
    final hash = _keccak(signingPayload);
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final v = BigInt.from(recoveryId + 35 + chainId * 2);
    final rawPayload = _rlpEncode([
      nonce,
      gasPrice,
      gasLimit,
      toBytes,
      value,
      data,
      v,
      signature.r,
      signature.s,
    ]);
    return hex.encode(rawPayload);
  }

  /// 签名 TRON 未签名交易。
  ///
  /// TRON 使用 `sha256(raw_data_hex)` 作为签名哈希，签名结果需要拼接 recoveryId，
  /// 并放入 transaction 的 `signature` 数组。
  Map<String, dynamic> _signTronTransaction({
    required String privateKeyHex,
    required Map<String, dynamic> transaction,
  }) {
    final rawDataHex = transaction['raw_data_hex']?.toString();
    if (rawDataHex == null || rawDataHex.isEmpty) {
      throw StateError('Missing TRON raw data');
    }
    final hash = _sha256(hexToBytes(rawDataHex));
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final signatureBytes = Uint8List.fromList([
      ..._bigIntToBytes(signature.r, length: 32),
      ..._bigIntToBytes(signature.s, length: 32),
      recoveryId,
    ]);

    final signed = Map<String, dynamic>.from(transaction);
    signed['signature'] = [hex.encode(signatureBytes)];
    return signed;
  }

  /// 构造 SOL 原生转账 message。
  Message _buildSolanaNativeTransferMessage({
    required Ed25519HDPublicKey fromPublicKey,
    required Ed25519HDPublicKey toPublicKey,
    required BigInt lamports,
  }) {
    return Message.only(
      SystemInstruction.transfer(
        fundingAccount: fromPublicKey,
        recipientAccount: toPublicKey,
        lamports: _solanaU64Amount(lamports, 'SOL transfer amount'),
      ),
    );
  }

  /// 构造 SPL Token 转账 message。
  ///
  /// 发送方需要已有该 mint 的 token account；接收方的 ATA 使用 idempotent 创建指令，
  /// 如果已存在不会失败。随后使用 `transferChecked` 携带 decimals 做安全转账。
  Future<Message> _buildSolanaTokenTransferMessage({
    required WalletChainRef chain,
    required Ed25519HDPublicKey ownerPublicKey,
    required Ed25519HDPublicKey recipientPublicKey,
    required ChainBalance asset,
    required BigInt amount,
  }) async {
    final mintAddress = asset.contractAddress;
    if (mintAddress == null || mintAddress.trim().isEmpty) {
      throw StateError('Missing Solana token mint');
    }
    final mintPublicKey = Ed25519HDPublicKey.fromBase58(
      normalizeSolanaAddress(mintAddress),
    );
    final sourceTokenAccount = await _findSolanaTokenAccount(
      chain: chain,
      ownerAddress: ownerPublicKey.toBase58(),
      mintAddress: mintPublicKey.toBase58(),
      minimumAmount: amount,
    );
    if (sourceTokenAccount == null) {
      throw StateError('Source Solana token account not found');
    }

    final sourceTokenPublicKey = Ed25519HDPublicKey.fromBase58(
      sourceTokenAccount,
    );
    final destinationTokenPublicKey = await findAssociatedTokenAddress(
      owner: recipientPublicKey,
      mint: mintPublicKey,
    );

    return Message(
      instructions: [
        AssociatedTokenAccountInstruction.createAccountIdempotent(
          funder: ownerPublicKey,
          address: destinationTokenPublicKey,
          owner: recipientPublicKey,
          mint: mintPublicKey,
          tokenProgramId: TokenProgramType.tokenProgram.id,
        ),
        TokenInstruction.transferChecked(
          source: sourceTokenPublicKey,
          mint: mintPublicKey,
          destination: destinationTokenPublicKey,
          owner: ownerPublicKey,
          amount: _solanaU64Amount(amount, '${asset.symbol} transfer amount'),
          decimals: asset.decimals,
        ),
      ],
    );
  }

  /// 查找发送方可用的 Solana token account。
  ///
  /// 如果能解析余额，会优先返回余额足够的账户；如果所有账户余额都不足则抛错。
  /// 如果节点没有返回可解析余额，则返回第一个账户作为兜底。
  Future<String?> _findSolanaTokenAccount({
    required WalletChainRef chain,
    required String ownerAddress,
    required String mintAddress,
    required BigInt minimumAmount,
  }) async {
    final data = await _solanaRpc(chain, 'getTokenAccountsByOwner', [
      ownerAddress,
      {'mint': mintAddress},
      {'encoding': 'jsonParsed'},
    ]);
    if (data is! Map) {
      return null;
    }
    final values = data['value'];
    if (values is! List || values.isEmpty) {
      return null;
    }
    String? fallbackAccount;
    var parsedAnyAmount = false;
    for (final item in values) {
      if (item is! Map) continue;
      final pubkey = item['pubkey']?.toString();
      if (pubkey == null || pubkey.isEmpty) continue;
      fallbackAccount ??= pubkey;

      final account = item['account'];
      final accountData = account is Map ? account['data'] : null;
      final parsed = accountData is Map ? accountData['parsed'] : null;
      final info = parsed is Map ? parsed['info'] : null;
      final tokenAmount = info is Map ? info['tokenAmount'] : null;
      final rawAmount = tokenAmount is Map
          ? BigInt.tryParse(tokenAmount['amount']?.toString() ?? '')
          : null;
      if (rawAmount == null) {
        throw StateError(
          'Unable to parse Solana token account balance for address: $pubkey',
        );
      }
      parsedAnyAmount = true;
      if (rawAmount >= minimumAmount) {
        return pubkey;
      }
    }
    if (parsedAnyAmount) {
      throw StateError('Source Solana token account balance is insufficient');
    }
    return fallbackAccount;
  }

  /// 对 32 字节哈希做 secp256k1 ECDSA 签名。
  ///
  /// 签名结果会 normalize 到 low-s，避免高 s 签名在部分节点或工具中被拒绝。
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
      final hash = digest.process(Uint8List.fromList(addr.toLowerCase().codeUnits));
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
      final digit = CryptoConstants.base58Alphabet.indexOf(String.fromCharCode(codeUnit));
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
