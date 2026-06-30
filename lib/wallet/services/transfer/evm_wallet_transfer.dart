part of '../wallet_transfer_service.dart';

extension _EvmWalletTransfer on WalletTransferService {
  Future<TransferFeeEstimate> _estimateEvmFee({
    required ChainBalance asset,
    required String toAddress,
    required String amount,
  }) async {
    final normalizedTo = WalletTransferService.normalizeEvmAddress(toAddress);
    final value = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final isNative = asset.isNative;
    final txTo = isNative ? normalizedTo : asset.contractAddress!;
    final txValue = isNative ? value : BigInt.zero;
    final data = isNative
        ? '0x'
        : WalletTransferService.erc20TransferData(normalizedTo, value);
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
          'value': WalletTransferService._hexQuantity(txValue),
          if (!isNative) 'data': data,
        },
      ]);
    } catch (_) {
      gasLimit = BigInt.from(
        isNative
            ? WalletTransferService._evmNativeGasLimit
            : WalletTransferService._evmTokenGasLimit,
      );
    }

    final feeWei = gasLimit * gasPrice;
    return TransferFeeEstimate(
      amount: WalletTransferService.rawUnitsToAmount(feeWei, 18),
      symbol: asset.chainRef.symbol,
      rawAmount: feeWei,
      isFallback: false,
    );
  }

  /// 估算 TRON 转账手续费。
  ///
  /// TRX 原生转账主要消耗带宽，TRC20 转账还需要能量。这里会读取链参数里的
  /// `getTransactionFee` 和 `getEnergyFee`，再按交易字节数和能量估算 sun。
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

    final normalizedTo = WalletTransferService.normalizeEvmAddress(toAddress);
    final value = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
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
        : WalletTransferService.hexToBytes(
            WalletTransferService.erc20TransferData(normalizedTo, value),
          );
    final gasLimit = isNative
        ? WalletTransferService._evmNativeGasLimit
        : WalletTransferService._evmTokenGasLimit;
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
    final toBytes = WalletTransferService.hexToBytes(
      WalletTransferService.normalizeBscAddress(toAddress),
    );
    final signingPayload = WalletTransferService._rlpEncode([
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
    final hash = WalletTransferService._keccak(signingPayload);
    final signature = _signHash(privateKeyHex, hash);
    final recoveryId = _findRecoveryId(privateKeyHex, hash, signature);
    final v = BigInt.from(recoveryId + 35 + chainId * 2);
    final rawPayload = WalletTransferService._rlpEncode([
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
}
