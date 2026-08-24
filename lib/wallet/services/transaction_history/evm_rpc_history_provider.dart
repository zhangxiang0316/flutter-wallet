part of '../wallet_transaction_history_service.dart';

extension _EvmRpcHistoryProvider on _EvmTransactionHistoryProvider {
  Future<List<WalletTransactionRecord>> _loadEvmTokenLogs({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final latestBlock = await _evmRpcBigInt(
      asset.chainRef,
      'eth_blockNumber',
      const [],
    );
    final latest = latestBlock.toInt();
    final start = math.max(
      0,
      latest - _evmLogScanBlockWindowFor(asset.chainRef),
    );
    return _loadEvmTokenLogsInRange(
      walletId: walletId,
      asset: asset,
      fromBlock: start,
      toBlock: latest,
    );
  }

  Future<List<WalletTransactionRecord>> _loadEvmTokenLogsInRange({
    required String walletId,
    required ChainBalance asset,
    required int fromBlock,
    required int toBlock,
  }) async {
    final walletTopic = _evmAddressTopic(asset.address);
    final records = <WalletTransactionRecord>[];
    final seenIds = <String>{};

    for (
      var chunkToBlock = toBlock;
      chunkToBlock >= fromBlock;
      chunkToBlock -= _EvmTransactionHistoryProvider._evmLogChunkSize
    ) {
      final chunkFromBlock = math.max(
        fromBlock,
        chunkToBlock - _EvmTransactionHistoryProvider._evmLogChunkSize + 1,
      );

      // ✅ 并行获取转出和转入日志
      final results = await Future.wait([
        _evmGetLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(chunkFromBlock)),
          'toBlock': _hexQuantity(BigInt.from(chunkToBlock)),
          'topics': [
            _EvmTransactionHistoryProvider._evmTransferEventTopic,
            walletTopic,
          ],
        }),
        _evmGetLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(chunkFromBlock)),
          'toBlock': _hexQuantity(BigInt.from(chunkToBlock)),
          'topics': [
            _EvmTransactionHistoryProvider._evmTransferEventTopic,
            null,
            walletTopic,
          ],
        }),
      ]);

      final outgoing = results[0];
      final incoming = results[1];

      // ✅ 并行处理所有日志
      final logFutures = [...outgoing, ...incoming].whereType<Map>().map(
        (log) =>
            _evmTokenRecordFromLog(walletId: walletId, asset: asset, log: log),
      );

      final processedRecords = await Future.wait(logFutures);

      for (final record in processedRecords) {
        if (record != null && seenIds.add(record.id)) {
          records.add(record);
        }
      }

      records.sort(_compareRecordTimeDesc);
      if (records.length >= _EvmTransactionHistoryProvider._historyLimit) {
        break;
      }
    }

    records.sort(_compareRecordTimeDesc);
    return records
        .take(_EvmTransactionHistoryProvider._historyLimit)
        .toList(growable: false);
  }

  int _evmLogScanBlockWindowFor(WalletChainRef chain) {
    if (chain.id == WalletChain.xLayer.id) {
      return _EvmTransactionHistoryProvider._xLayerLogScanBlockWindow;
    }
    if (chain.id == WalletChain.arbitrum.id) {
      return _EvmTransactionHistoryProvider._arbitrumLogScanBlockWindow;
    }
    return _EvmTransactionHistoryProvider._evmLogScanBlockWindow;
  }

  int _evmLogPageBlockWindowFor(WalletChainRef chain) {
    if (chain.id == WalletChain.arbitrum.id) {
      return _EvmTransactionHistoryProvider._arbitrumLogScanBlockWindow;
    }
    return _EvmTransactionHistoryProvider._evmLogPageBlockWindow;
  }

  Future<WalletTransactionRecord?> _evmTokenRecordFromLog({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> log,
  }) async {
    final txHash = log['transactionHash']?.toString() ?? '';
    final topics = log['topics'];
    if (txHash.isEmpty || topics is! List || topics.length < 3) return null;

    final receipt = await _evmRpcMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );

    return _evmTokenRecordFromReceiptLog(
      walletId: walletId,
      asset: asset,
      receipt: receipt,
      log: log,
      txHash: txHash,
    );
  }

  Future<WalletTransactionRecord?> _loadEvmNativeRecordByHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final receipt = await _evmRpcNullableMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );
    if (receipt == null) return null;

    final transaction = await _evmRpcNullableMap(
      asset.chainRef,
      'eth_getTransactionByHash',
      [txHash],
    );
    if (transaction == null) return null;

    final actualTxHash =
        transaction['hash']?.toString() ??
        receipt['transactionHash']?.toString() ??
        txHash;
    final from = _normalizeEvmDisplayAddress(
      transaction['from']?.toString() ?? receipt['from']?.toString() ?? '',
    );
    final to = _normalizeEvmDisplayAddress(
      transaction['to']?.toString() ?? receipt['to']?.toString() ?? '',
    );
    final rawValue = _rpcQuantityToBigInt(transaction['value']);
    final blockNumber = _hexIntFromObject(
      transaction['blockNumber'] ?? receipt['blockNumber'],
    );

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, actualTxHash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: actualTxHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, asset.decimals),
      decimals: asset.decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _evmReceiptStatus(receipt),
      source: WalletTransactionSource.remote,
      feeAmount: _evmReceiptFeeAmount(
        receipt,
        fallbackGasPrice: transaction['gasPrice'],
      ),
      feeSymbol: asset.chainRef.symbol,
      blockNumber: blockNumber,
      timestamp: await _evmReceiptTimestamp(asset.chainRef, receipt: receipt),
    );
  }

  Future<WalletTransactionRecord?> _loadEvmTokenRecordByHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final receipt = await _evmRpcNullableMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );
    if (receipt == null) return null;

    final logs = receipt['logs'];
    if (logs is! List) return null;

    for (final log in logs.whereType<Map>()) {
      final record = await _evmTokenRecordFromReceiptLog(
        walletId: walletId,
        asset: asset,
        receipt: receipt,
        log: log,
        txHash: txHash,
      );
      if (record != null) return record;
    }

    return null;
  }

  Future<WalletTransactionRecord?> _evmTokenRecordFromReceiptLog({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> receipt,
    required Map<dynamic, dynamic> log,
    required String txHash,
  }) async {
    if (!_isMatchingEvmTransferLog(asset, log)) return null;

    final topics = log['topics'];
    if (topics is! List || topics.length < 3) return null;

    final from = _evmAddressFromTopic(topics[1]?.toString() ?? '');
    final to = _evmAddressFromTopic(topics[2]?.toString() ?? '');
    final direction = _directionForAddress(
      walletAddress: asset.address,
      fromAddress: from,
      toAddress: to,
      normalize: _normalizeEvmCompareAddress,
    );
    if (direction == WalletTransactionDirection.unknown) return null;

    final actualTxHash =
        log['transactionHash']?.toString() ??
        receipt['transactionHash']?.toString() ??
        txHash;
    final rawValue = _rpcQuantityToBigInt(log['data']);
    final blockNumber = _hexIntFromObject(
      log['blockNumber'] ?? receipt['blockNumber'],
    );
    final eventIndex = _normalizedEventIndex(log['logIndex']);

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$actualTxHash:${eventIndex ?? ''}'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: actualTxHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, asset.decimals),
      decimals: asset.decimals,
      direction: direction,
      status: _evmReceiptStatus(receipt),
      source: WalletTransactionSource.remote,
      eventIndex: eventIndex,
      contractAddress: asset.contractAddress,
      feeAmount: _evmReceiptFeeAmount(receipt),
      feeSymbol: asset.chainRef.symbol,
      blockNumber: blockNumber,
      timestamp: await _evmReceiptTimestamp(
        asset.chainRef,
        receipt: receipt,
        log: log,
      ),
    );
  }

  bool _isMatchingEvmTransferLog(
    ChainBalance asset,
    Map<dynamic, dynamic> log,
  ) {
    final logAddress = log['address']?.toString() ?? '';
    if (logAddress.isNotEmpty &&
        !_sameEvmAddress(logAddress, asset.contractAddress ?? '')) {
      return false;
    }

    final topics = log['topics'];
    if (topics is! List || topics.length < 3) return false;
    return topics.first.toString().toLowerCase() ==
        _EvmTransactionHistoryProvider._evmTransferEventTopic.toLowerCase();
  }

  WalletTransactionStatus _evmReceiptStatus(Map<dynamic, dynamic> receipt) {
    final status = receipt['status']?.toString().toLowerCase() ?? '';
    if (status == '0x0' || status == '0') {
      return WalletTransactionStatus.failed;
    }
    if (status == '0x1' || status == '1') {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  String? _evmReceiptFeeAmount(
    Map<dynamic, dynamic> receipt, {
    Object? fallbackGasPrice,
  }) {
    final gasUsed = _rpcQuantityToBigInt(receipt['gasUsed']);
    final gasPrice = _rpcQuantityToBigInt(
      receipt['effectiveGasPrice'] ?? receipt['gasPrice'] ?? fallbackGasPrice,
    );
    if (gasUsed <= BigInt.zero || gasPrice <= BigInt.zero) return null;
    return WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18);
  }

  Future<DateTime?> _evmReceiptTimestamp(
    WalletChainRef chain, {
    required Map<dynamic, dynamic> receipt,
    Map<dynamic, dynamic>? log,
  }) async {
    final inlineTimestamp = _dateTimeFromRpcSeconds(
      log?['blockTimestamp'] ?? receipt['blockTimestamp'],
    );
    if (inlineTimestamp != null) return inlineTimestamp;

    final blockNumber = _rpcQuantityParam(
      log?['blockNumber'] ?? receipt['blockNumber'],
    );
    if (blockNumber == null) return null;

    final block = await _evmRpcNullableMap(chain, 'eth_getBlockByNumber', [
      blockNumber,
      false,
    ]);
    if (block == null) return null;
    return _dateTimeFromRpcSeconds(block['timestamp']);
  }

  DateTime? _dateTimeFromRpcSeconds(Object? value) {
    final seconds = _hexIntFromObject(value);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  int? _hexIntFromObject(Object? value) {
    if (value is int) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('0x')) {
      return _parseHexQuantity(text).toInt();
    }
    return int.tryParse(text);
  }

  BigInt _rpcQuantityToBigInt(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return BigInt.zero;
    if (text.toLowerCase().startsWith('0x')) {
      return _parseHexQuantity(text);
    }
    return BigInt.tryParse(text) ?? BigInt.zero;
  }

  String? _rpcQuantityParam(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('0x')) return text;
    final decimal = BigInt.tryParse(text);
    if (decimal == null) return null;
    return _hexQuantity(decimal);
  }

  Future<dynamic> _evmRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    try {
      final data = await RpcRetryHelper.executeJsonRpc(
        dio: dio,
        rpcUrls: _evmRpcUrls(chain),
        method: method,
        params: params,
        chainName: chain.name,
        logName: 'WalletTransactionHistoryService',
      );
      if (data.containsKey('result')) {
        return data['result'];
      }
      throw _historyLoadException('Invalid ${chain.name} RPC data', data);
    } catch (error) {
      throw _historyLoadException('${chain.name} RPC failed', error);
    }
  }

  Future<BigInt> _evmRpcBigInt(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    return _parseHexQuantity((await _evmRpc(chain, method, params)).toString());
  }

  Future<Map<dynamic, dynamic>> _evmRpcMap(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _evmRpc(chain, method, params);
    if (result is Map) {
      return result;
    }
    throw _historyLoadException(
      'Invalid ${chain.name} $method response',
      result,
    );
  }

  Future<Map<dynamic, dynamic>?> _evmRpcNullableMap(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _evmRpc(chain, method, params);
    if (result == null) return null;
    if (result is Map) {
      return result;
    }
    throw _historyLoadException(
      'Invalid ${chain.name} $method response',
      result,
    );
  }

  Future<List<dynamic>> _evmGetLogs(
    WalletChainRef chain,
    Map<String, dynamic> filter,
  ) async {
    final result = await _evmRpc(chain, 'eth_getLogs', [filter]);
    return result is List ? result : const [];
  }
}
