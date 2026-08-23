part of '../wallet_transaction_history_service.dart';

class _EvmTransactionHistoryProvider with _TransactionHistoryProviderHelpers {
  _EvmTransactionHistoryProvider({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const int _historyLimit = _transactionHistoryPageSize;
  static const int _bscExplorerPageSize = 100;
  static const int _bscExplorerMaxScanPages = 3;
  static const int _evmLogChunkSize = 50000;
  static const int _evmLogPageBlockWindow = 500000;
  static const int _evmLogScanBlockWindow = 5000000;
  static const int _xLayerLogScanBlockWindow = 500000;
  static const int _arbitrumLogScanBlockWindow = 200000;
  static const int _blockscoutMaxPages = 4;
  static const Duration _limitedLogFallbackTimeout = Duration(seconds: 4);

  static const String _evmTransferEventTopic =
      CryptoConstants.evmTransferEventTopic;

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? lastExplorerError;
    var hasSuccessfulExplorer = false;
    final isLoadMore = cursor != null;
    if (cursor?.evmLogBeforeBlock != null &&
        _supportsEvmTokenLogPaging(asset)) {
      return _loadEvmTokenLogRecordPage(
        walletId: walletId,
        asset: asset,
        beforeBlock: cursor!.evmLogBeforeBlock!,
      );
    }

    for (final provider in _evmHistoryProviders(asset.chainRef)) {
      if (cursor?.evmPage != null &&
          provider.type != _EvmHistoryProviderType.etherscanCompatible) {
        continue;
      }
      if (cursor?.blockscoutParams != null &&
          provider.type != _EvmHistoryProviderType.blockscoutV2) {
        continue;
      }
      try {
        final result = switch (provider.type) {
          _EvmHistoryProviderType.etherscanCompatible =>
            await _loadEvmExplorerRecordPage(
              apiUrl: provider.url,
              apiKey: provider.apiKey,
              walletId: walletId,
              asset: asset,
              page: cursor?.evmPage ?? 1,
            ),
          _EvmHistoryProviderType.blockscoutV2 =>
            await _loadBlockscoutRecordPage(
              baseUrl: provider.url,
              walletId: walletId,
              asset: asset,
              cursor: cursor?.blockscoutParams,
            ),
        };
        hasSuccessfulExplorer = true;
        if (result.records.isNotEmpty || result.hasMore) {
          return result;
        }
        if (asset.isNative) return result;
      } catch (error) {
        lastExplorerError = error;
        SafeLog.error(
          '${asset.chainRef.name} explorer history failed at '
          '${provider.url}: $error',
          name: 'WalletTransactionHistoryService',
        );
      }
    }

    if (asset.isNative) {
      if (isLoadMore) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
          emptyReason: TransactionHistoryFailureKind.noRecords,
        );
      }
      if (_nativeHistoryCanBeEmpty(asset.chainRef)) {
        SafeLog.error(
          '${asset.chainRef.name} native history provider failed; '
          'returning empty result: '
          '${lastExplorerError ?? 'no explorer provider'}',
          name: 'WalletTransactionHistoryService',
        );
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
          emptyReason: TransactionHistoryFailureKind.noRecords,
        );
      }
      throw _historyLoadException(
        '${asset.chainRef.name} native history failed',
        lastExplorerError,
      );
    }

    try {
      if (isLoadMore) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
          emptyReason: TransactionHistoryFailureKind.noRecords,
        );
      }
      if (_supportsEvmTokenLogPaging(asset)) {
        return await _loadEvmTokenLogRecordPage(
          walletId: walletId,
          asset: asset,
        );
      }
      final records = await _loadEvmTokenLogs(walletId: walletId, asset: asset)
          .timeout(
            _limitedLogFallbackTimeout,
            onTimeout: () {
              SafeLog.error(
                '${asset.chainRef.name} token log fallback timed out',
                name: 'WalletTransactionHistoryService',
              );
              return const <WalletTransactionRecord>[];
            },
          );
      return TransactionHistoryPageResult(
        records: records,
        nextCursor: null,
        emptyReason: records.isEmpty
            ? TransactionHistoryFailureKind.noRecords
            : null,
      );
    } catch (error) {
      if (hasSuccessfulExplorer || _tokenHistoryCanBeEmpty(asset.chainRef)) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
          emptyReason: TransactionHistoryFailureKind.noRecords,
        );
      }
      throw _historyLoadException(
        '${asset.chainRef.name} token history failed',
        error,
      );
    }
  }

  Future<WalletTransactionRecord?> loadRecordByTransactionHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final normalizedHash = txHash.trim();
    if (normalizedHash.isEmpty) return null;

    try {
      if (asset.isNative) {
        return _loadEvmNativeRecordByHash(
          walletId: walletId,
          asset: asset,
          txHash: normalizedHash,
        );
      }
      return _loadEvmTokenRecordByHash(
        walletId: walletId,
        asset: asset,
        txHash: normalizedHash,
      );
    } catch (error) {
      SafeLog.error(
        '${asset.chainRef.name} transaction hash lookup failed: $error',
        name: 'WalletTransactionHistoryService',
      );
      return null;
    }
  }

  bool _supportsEvmTokenLogPaging(ChainBalance asset) {
    return asset.chainRef.isEvm &&
        !asset.isNative &&
        (asset.contractAddress?.trim().isNotEmpty ?? false);
  }

  bool _nativeHistoryCanBeEmpty(WalletChainRef chain) {
    return chain.id == WalletChain.bsc.id || chain.id == WalletChain.xLayer.id;
  }

  bool _tokenHistoryCanBeEmpty(WalletChainRef chain) {
    return chain.id == WalletChain.bsc.id || chain.id == WalletChain.xLayer.id;
  }

  Future<TransactionHistoryPageResult> _loadEvmTokenLogRecordPage({
    required String walletId,
    required ChainBalance asset,
    int? beforeBlock,
  }) async {
    final latestBlock = beforeBlock == null
        ? await _evmRpcBigInt(asset.chainRef, 'eth_blockNumber', const [])
        : BigInt.from(beforeBlock);
    final toBlock = latestBlock.toInt();
    if (toBlock <= 0) {
      return const TransactionHistoryPageResult(
        records: [],
        nextCursor: null,
        emptyReason: TransactionHistoryFailureKind.noRecords,
      );
    }

    final fromBlock = math.max(
      0,
      toBlock - _evmLogPageBlockWindowFor(asset.chainRef) + 1,
    );
    final records = await _loadEvmTokenLogsInRange(
      walletId: walletId,
      asset: asset,
      fromBlock: fromBlock,
      toBlock: toBlock,
    );

    return TransactionHistoryPageResult(
      records: records,
      nextCursor: fromBlock > 0
          ? TransactionHistoryCursor.evmLogBeforeBlock(fromBlock - 1)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  Future<TransactionHistoryPageResult> _loadEvmExplorerRecordPage({
    required String apiUrl,
    String? apiKey,
    required String walletId,
    required ChainBalance asset,
    required int page,
  }) async {
    final requestLimit = _evmExplorerRequestLimit(asset.chainRef);
    final maxScanPages = _evmExplorerScanPages(asset.chainRef);
    final normalizedApiKey = apiKey?.trim() ?? '';
    final records = <WalletTransactionRecord>[];
    final seenIds = <String>{};
    final transferCountsByHash = <String, int>{};
    var currentPage = page;
    var hasMoreRawPages = false;

    for (var scanPage = 0; scanPage < maxScanPages; scanPage++) {
      final response = await dio.get(
        apiUrl,
        queryParameters: {
          'module': 'account',
          'action': asset.isNative ? 'txlist' : 'tokentx',
          'address': asset.address,
          if (!asset.isNative) 'contractaddress': asset.contractAddress,
          'page': currentPage,
          'offset': requestLimit,
          'sort': 'desc',
          if (_isEtherscanV2Api(apiUrl) && asset.chainRef.evmChainId != null)
            'chainid': asset.chainRef.evmChainId,
          if (normalizedApiKey.isNotEmpty) 'apikey': normalizedApiKey,
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw _historyLoadException(
          'Invalid ${asset.chainRef.name} explorer response',
          data,
        );
      }

      final result = data['result'];
      if (result is List) {
        hasMoreRawPages = result.length >= requestLimit;
        for (final item in result.whereType<Map>()) {
          final txHash = item['hash']?.toString().toLowerCase() ?? '';
          final transferIndex = asset.isNative || txHash.isEmpty
              ? null
              : transferCountsByHash
                    .update(txHash, (count) => count + 1, ifAbsent: () => 0)
                    .toString();
          final record = asset.isNative
              ? _evmNativeRecordFromExplorer(
                  walletId: walletId,
                  asset: asset,
                  item: item,
                )
              : _evmTokenRecordFromExplorer(
                  walletId: walletId,
                  asset: asset,
                  item: item,
                  transferIndex: transferIndex,
                );
          if (record == null) continue;
          if (seenIds.add(record.id)) {
            records.add(record);
          }
        }
        records.sort(_compareRecordTimeDesc);
        if (records.length >= _historyLimit || !hasMoreRawPages) {
          break;
        }
        currentPage += 1;
        continue;
      }

      final message = data['message']?.toString().toLowerCase() ?? '';
      final resultText = result?.toString().toLowerCase() ?? '';
      if (message.contains('no transactions') ||
          resultText.contains('no transactions')) {
        hasMoreRawPages = false;
        break;
      }
      final errorText =
          data['result']?.toString() ??
          data['message']?.toString() ??
          'Explorer request failed';
      throw _historyLoadException(
        '${asset.chainRef.name} explorer request failed',
        errorText,
      );
    }

    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: hasMoreRawPages
          ? TransactionHistoryCursor.evmExplorerPage(currentPage + 1)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  int _evmExplorerRequestLimit(WalletChainRef chain) {
    if (chain.id == WalletChain.bsc.id) return _bscExplorerPageSize;
    return _historyLimit;
  }

  int _evmExplorerScanPages(WalletChainRef chain) {
    if (chain.id == WalletChain.bsc.id) return _bscExplorerMaxScanPages;
    return 1;
  }

  Future<TransactionHistoryPageResult> _loadBlockscoutRecordPage({
    required String baseUrl,
    required String walletId,
    required ChainBalance asset,
    String? cursor,
  }) async {
    final apiBase = _blockscoutApiBase(baseUrl);
    final path = asset.isNative ? 'transactions' : 'token-transfers';
    var queryParameters =
        _decodeBlockscoutCursor(cursor) ??
        (asset.isNative
            ? <String, dynamic>{}
            : <String, dynamic>{'type': 'ERC-20'});
    if (!asset.isNative) {
      queryParameters['type'] = 'ERC-20';
    }
    final records = <WalletTransactionRecord>[];
    final seenIds = <String>{};
    final transferCountsByHash = <String, int>{};
    TransactionHistoryCursor? nextCursor;

    for (var page = 0; page < _blockscoutMaxPages; page++) {
      final requestQueryParameters = queryParameters;
      final response = await dio.get(
        '$apiBase/addresses/${Uri.encodeComponent(asset.address)}/$path',
        queryParameters: requestQueryParameters.isEmpty
            ? null
            : requestQueryParameters,
      );
      final data = response.data;
      if (data is! Map) {
        throw _historyLoadException(
          'Invalid ${asset.chainRef.name} Blockscout response',
          data,
        );
      }

      final items = data['items'];
      if (items is! List) {
        throw _historyLoadException(
          'Invalid ${asset.chainRef.name} Blockscout items',
          data,
        );
      }
      for (final item in items.whereType<Map>()) {
        final txHash = item['transaction_hash']?.toString().toLowerCase() ?? '';
        final transferIndex = asset.isNative || txHash.isEmpty
            ? null
            : transferCountsByHash
                  .update(txHash, (count) => count + 1, ifAbsent: () => 0)
                  .toString();
        final record = asset.isNative
            ? _evmNativeRecordFromBlockscout(
                walletId: walletId,
                asset: asset,
                item: item,
              )
            : _evmTokenRecordFromBlockscout(
                walletId: walletId,
                asset: asset,
                item: item,
                transferIndex: transferIndex,
              );
        if (record != null && seenIds.add(record.id)) {
          records.add(record);
        }
      }
      records.sort(_compareRecordTimeDesc);
      if (records.length >= _historyLimit) {
        break;
      }

      final nextPageParams = data['next_page_params'];
      if (nextPageParams is! Map || nextPageParams.isEmpty) {
        break;
      }
      queryParameters = {
        for (final entry in nextPageParams.entries)
          entry.key.toString(): entry.value,
        if (!asset.isNative) 'type': 'ERC-20',
      };
      nextCursor = TransactionHistoryCursor.blockscoutPage(
        jsonEncode(queryParameters),
      );
    }

    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: nextCursor,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

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
      chunkToBlock -= _evmLogChunkSize
    ) {
      final chunkFromBlock = math.max(
        fromBlock,
        chunkToBlock - _evmLogChunkSize + 1,
      );

      // ✅ 并行获取转出和转入日志
      final results = await Future.wait([
        _evmGetLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(chunkFromBlock)),
          'toBlock': _hexQuantity(BigInt.from(chunkToBlock)),
          'topics': [_evmTransferEventTopic, walletTopic],
        }),
        _evmGetLogs(asset.chainRef, {
          'address': asset.contractAddress,
          'fromBlock': _hexQuantity(BigInt.from(chunkFromBlock)),
          'toBlock': _hexQuantity(BigInt.from(chunkToBlock)),
          'topics': [_evmTransferEventTopic, null, walletTopic],
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
      if (records.length >= _historyLimit) {
        break;
      }
    }

    records.sort(_compareRecordTimeDesc);
    return records.take(_historyLimit).toList(growable: false);
  }

  int _evmLogScanBlockWindowFor(WalletChainRef chain) {
    if (chain.id == WalletChain.xLayer.id) {
      return _xLayerLogScanBlockWindow;
    }
    if (chain.id == WalletChain.arbitrum.id) {
      return _arbitrumLogScanBlockWindow;
    }
    return _evmLogScanBlockWindow;
  }

  int _evmLogPageBlockWindowFor(WalletChainRef chain) {
    if (chain.id == WalletChain.arbitrum.id) {
      return _arbitrumLogScanBlockWindow;
    }
    return _evmLogPageBlockWindow;
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
        _evmTransferEventTopic.toLowerCase();
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
