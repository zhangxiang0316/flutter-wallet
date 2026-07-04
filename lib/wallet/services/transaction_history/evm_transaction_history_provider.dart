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

    for (final provider in this._evmHistoryProviders(asset.chainRef)) {
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
        developer.log(
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
        developer.log(
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
        return _loadEvmTokenLogRecordPage(walletId: walletId, asset: asset);
      }
      final records = await _loadEvmTokenLogs(walletId: walletId, asset: asset)
          .timeout(
            _limitedLogFallbackTimeout,
            onTimeout: () {
              developer.log(
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
      if (hasSuccessfulExplorer) {
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

  bool _supportsEvmTokenLogPaging(ChainBalance asset) {
    return asset.chainRef.isEvm &&
        !asset.isNative &&
        (asset.contractAddress?.trim().isNotEmpty ?? false);
  }

  bool _nativeHistoryCanBeEmpty(WalletChainRef chain) {
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
          if (this._isEtherscanV2Api(apiUrl) &&
              asset.chainRef.evmChainId != null)
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
        for (final record
            in result
                .whereType<Map>()
                .map(
                  (item) => asset.isNative
                      ? _evmNativeRecordFromExplorer(
                          walletId: walletId,
                          asset: asset,
                          item: item,
                        )
                      : _evmTokenRecordFromExplorer(
                          walletId: walletId,
                          asset: asset,
                          item: item,
                        ),
                )
                .whereType<WalletTransactionRecord>()) {
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
    final apiBase = this._blockscoutApiBase(baseUrl);
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

    final from = _evmAddressFromTopic(topics[1]?.toString() ?? '');
    final to = _evmAddressFromTopic(topics[2]?.toString() ?? '');
    final rawValue = _parseHexQuantity(log['data']?.toString() ?? '0x0');
    final blockHex = log['blockNumber']?.toString() ?? '0x0';
    final blockNumber = _parseHexQuantity(blockHex).toInt();
    final receipt = await _evmRpcMap(
      asset.chainRef,
      'eth_getTransactionReceipt',
      [txHash],
    );
    final block = await _evmRpcMap(asset.chainRef, 'eth_getBlockByNumber', [
      blockHex,
      false,
    ]);
    final gasUsed = _parseHexQuantity(receipt['gasUsed']?.toString() ?? '0x0');
    final gasPrice = _parseHexQuantity(
      receipt['effectiveGasPrice']?.toString() ??
          receipt['gasPrice']?.toString() ??
          '0x0',
    );

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:$blockNumber:${log['logIndex']}'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
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
      status: receipt['status']?.toString() == '0x0'
          ? WalletTransactionStatus.failed
          : WalletTransactionStatus.success,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: blockNumber,
      timestamp: _dateTimeFromSeconds(
        _parseHexQuantity(block['timestamp']?.toString() ?? '0x0').toString(),
      ),
    );
  }

  Future<dynamic> _evmRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    try {
      final data = await RpcRetryHelper.executeJsonRpc(
        dio: dio,
        rpcUrls: this._evmRpcUrls(chain),
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

  Future<List<dynamic>> _evmGetLogs(
    WalletChainRef chain,
    Map<String, dynamic> filter,
  ) async {
    final result = await _evmRpc(chain, 'eth_getLogs', [filter]);
    return result is List ? result : const [];
  }
}
