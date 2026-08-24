part of '../wallet_transaction_history_service.dart';

class _EvmRpcHistoryClient with _TransactionHistoryProviderHelpers {
  _EvmRpcHistoryClient({
    required this.dio,
    required this.apiConfig,
    required _EvmHistoryProviderRouter router,
    required _EvmHistoryPaginator paginator,
    required _EvmTransactionRecordParser parser,
  }) : _router = router,
       _paginator = paginator,
       _parser = parser;

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  final _EvmHistoryProviderRouter _router;
  final _EvmHistoryPaginator _paginator;
  final _EvmTransactionRecordParser _parser;

  static const String _transferEventTopic =
      CryptoConstants.evmTransferEventTopic;

  Future<List<WalletTransactionRecord>> loadTokenLogs({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final latestBlock = await rpcBigInt(
      asset.chainRef,
      'eth_blockNumber',
      const [],
    );
    final latest = latestBlock.toInt();
    final start = math.max(
      0,
      latest - _paginator.logScanBlockWindow(asset.chainRef),
    );
    return loadTokenLogsInRange(
      walletId: walletId,
      asset: asset,
      fromBlock: start,
      toBlock: latest,
    );
  }

  Future<List<WalletTransactionRecord>> loadTokenLogsInRange({
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
      chunkToBlock -= _EvmHistoryPaginator.logChunkSize
    ) {
      final chunkFromBlock = math.max(
        fromBlock,
        chunkToBlock - _EvmHistoryPaginator.logChunkSize + 1,
      );

      // ✅ 并行获取转出和转入日志
      final results = await Future.wait([
        _getLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(chunkFromBlock)),
          'toBlock': _hexQuantity(BigInt.from(chunkToBlock)),
          'topics': [_transferEventTopic, walletTopic],
        }),
        _getLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(chunkFromBlock)),
          'toBlock': _hexQuantity(BigInt.from(chunkToBlock)),
          'topics': [_transferEventTopic, null, walletTopic],
        }),
      ]);

      final outgoing = results[0];
      final incoming = results[1];

      // ✅ 并行处理所有日志
      final logFutures = [...outgoing, ...incoming].whereType<Map>().map(
        (log) =>
            _tokenRecordFromLog(walletId: walletId, asset: asset, log: log),
      );

      final processedRecords = await Future.wait(logFutures);

      for (final record in processedRecords) {
        if (record != null && seenIds.add(record.id)) {
          records.add(record);
        }
      }

      records.sort(_compareRecordTimeDesc);
      if (records.length >= _EvmHistoryPaginator.historyLimit) {
        break;
      }
    }

    records.sort(_compareRecordTimeDesc);
    return records
        .take(_EvmHistoryPaginator.historyLimit)
        .toList(growable: false);
  }

  Future<WalletTransactionRecord?> _tokenRecordFromLog({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> log,
  }) async {
    final txHash = log['transactionHash']?.toString() ?? '';
    final topics = log['topics'];
    if (txHash.isEmpty || topics is! List || topics.length < 3) return null;

    final receipt = await _rpcMap(asset.chainRef, 'eth_getTransactionReceipt', [
      txHash,
    ]);

    return _tokenRecordFromReceiptLog(
      walletId: walletId,
      asset: asset,
      receipt: receipt,
      log: log,
      txHash: txHash,
    );
  }

  Future<WalletTransactionRecord?> loadNativeRecordByHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final receipt = await _rpcNullableMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );
    if (receipt == null) return null;

    final transaction = await _rpcNullableMap(
      asset.chainRef,
      'eth_getTransactionByHash',
      [txHash],
    );
    if (transaction == null) return null;

    return _parser.nativeRecordFromRpc(
      walletId: walletId,
      asset: asset,
      requestedHash: txHash,
      transaction: transaction,
      receipt: receipt,
      timestamp: await _receiptTimestamp(asset.chainRef, receipt: receipt),
    );
  }

  Future<WalletTransactionRecord?> loadTokenRecordByHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final receipt = await _rpcNullableMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );
    if (receipt == null) return null;

    final logs = receipt['logs'];
    if (logs is! List) return null;

    for (final log in logs.whereType<Map>()) {
      final record = await _tokenRecordFromReceiptLog(
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

  Future<WalletTransactionRecord?> _tokenRecordFromReceiptLog({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> receipt,
    required Map<dynamic, dynamic> log,
    required String txHash,
  }) async {
    if (!_parser.isMatchingTransferLog(asset, log)) return null;
    return _parser.tokenRecordFromRpcLog(
      walletId: walletId,
      asset: asset,
      requestedHash: txHash,
      receipt: receipt,
      log: log,
      timestamp: await _receiptTimestamp(
        asset.chainRef,
        receipt: receipt,
        log: log,
      ),
    );
  }

  Future<DateTime?> _receiptTimestamp(
    WalletChainRef chain, {
    required Map<dynamic, dynamic> receipt,
    Map<dynamic, dynamic>? log,
  }) async {
    final inlineTimestamp = _parser.dateTimeFromRpcSeconds(
      log?['blockTimestamp'] ?? receipt['blockTimestamp'],
    );
    if (inlineTimestamp != null) return inlineTimestamp;

    final blockNumber = _parser.rpcQuantityParam(
      log?['blockNumber'] ?? receipt['blockNumber'],
    );
    if (blockNumber == null) return null;

    final block = await _rpcNullableMap(chain, 'eth_getBlockByNumber', [
      blockNumber,
      false,
    ]);
    if (block == null) return null;
    return _parser.dateTimeFromRpcSeconds(block['timestamp']);
  }

  Future<dynamic> _rpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    try {
      final data = await RpcRetryHelper.executeJsonRpc(
        dio: dio,
        rpcUrls: _router.rpcUrls(chain),
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

  Future<BigInt> rpcBigInt(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    return _parseHexQuantity((await _rpc(chain, method, params)).toString());
  }

  Future<Map<dynamic, dynamic>> _rpcMap(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _rpc(chain, method, params);
    if (result is Map) {
      return result;
    }
    throw _historyLoadException(
      'Invalid ${chain.name} $method response',
      result,
    );
  }

  Future<Map<dynamic, dynamic>?> _rpcNullableMap(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    final result = await _rpc(chain, method, params);
    if (result == null) return null;
    if (result is Map) {
      return result;
    }
    throw _historyLoadException(
      'Invalid ${chain.name} $method response',
      result,
    );
  }

  Future<List<dynamic>> _getLogs(
    WalletChainRef chain,
    Map<String, dynamic> filter,
  ) async {
    final result = await _rpc(chain, 'eth_getLogs', [filter]);
    return result is List ? result : const [];
  }
}
