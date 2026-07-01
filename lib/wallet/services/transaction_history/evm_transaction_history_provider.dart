part of '../wallet_transaction_history_service.dart';

class _EvmTransactionHistoryProvider with _TransactionHistoryProviderHelpers {
  _EvmTransactionHistoryProvider({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const int _historyLimit = 30;
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

  static const Map<String, String> _evmExplorerApiUrls = {
    'bsc': 'https://api.bscscan.com/api',
    'ethereum': 'https://api.etherscan.io/api',
  };

  static const String _etherscanV2ApiUrl = 'https://api.etherscan.io/v2/api';

  static const Map<String, List<String>> _evmBlockscoutBaseUrls = {
    'ethereum': ['https://eth.blockscout.com'],
  };

  static const Map<String, List<String>> _evmRpcFallbacks = {
    'bsc': [
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-rpc.publicnode.com',
    ],
    'ethereum': [
      'https://ethereum-rpc.publicnode.com',
      'https://eth.llamarpc.com',
    ],
    'x-layer': ['https://rpc.xlayer.tech', 'https://xlayerrpc.okx.com'],
    'arbitrum': [
      'https://arb1.arbitrum.io/rpc',
      'https://arbitrum-one-rpc.publicnode.com',
    ],
  };

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
        );
      }
      throw StateError(
        '${asset.chainRef.name} native history failed: '
        '${lastExplorerError ?? 'no explorer provider'}',
      );
    }

    try {
      if (isLoadMore) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
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
      return TransactionHistoryPageResult(records: records, nextCursor: null);
    } catch (error) {
      if (hasSuccessfulExplorer) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
        );
      }
      rethrow;
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
      return const TransactionHistoryPageResult(records: [], nextCursor: null);
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
          if (_isEtherscanV2Api(apiUrl) && asset.chainRef.evmChainId != null)
            'chainid': asset.chainRef.evmChainId,
          if (normalizedApiKey.isNotEmpty) 'apikey': normalizedApiKey,
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw StateError('Invalid ${asset.chainRef.name} explorer response');
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
      throw StateError(
        data['result']?.toString() ??
            data['message']?.toString() ??
            'Explorer request failed',
      );
    }

    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: hasMoreRawPages
          ? TransactionHistoryCursor.evmExplorerPage(currentPage + 1)
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
        throw StateError('Invalid ${asset.chainRef.name} Blockscout response');
      }

      final items = data['items'];
      if (items is! List) {
        throw StateError('Invalid ${asset.chainRef.name} Blockscout items');
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
    );
  }

  Map<String, dynamic>? _decodeBlockscoutCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    try {
      final decoded = jsonDecode(cursor);
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      };
    } catch (_) {
      return null;
    }
  }

  WalletTransactionRecord? _evmNativeRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeEvmDisplayAddress(item['to']?.toString() ?? '');
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final gasUsed =
        BigInt.tryParse(item['gasUsed']?.toString() ?? '') ?? BigInt.zero;
    final gasPrice =
        BigInt.tryParse(item['gasPrice']?.toString() ?? '') ?? BigInt.zero;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
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
      status: _evmExplorerStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(item['timeStamp']),
    );
  }

  WalletTransactionRecord? _evmTokenRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;
    final contractAddress = item['contractAddress']?.toString() ?? '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final decimals =
        int.tryParse(item['tokenDecimal']?.toString() ?? '') ?? asset.decimals;
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final from = _normalizeEvmDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeEvmDisplayAddress(item['to']?.toString() ?? '');
    final gasUsed =
        BigInt.tryParse(item['gasUsed']?.toString() ?? '') ?? BigInt.zero;
    final gasPrice =
        BigInt.tryParse(item['gasPrice']?.toString() ?? '') ?? BigInt.zero;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
      decimals: decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _evmExplorerStatus(item),
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(item['timeStamp']),
    );
  }

  WalletTransactionRecord? _evmNativeRecordFromBlockscout({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(_blockscoutAddress(item['from']));
    final to = _normalizeEvmDisplayAddress(_blockscoutAddress(item['to']));
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final feeValue = _blockscoutFeeValue(item);

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
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
      status: _blockscoutStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: feeValue > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(feeValue, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['timestamp']),
    );
  }

  WalletTransactionRecord? _evmTokenRecordFromBlockscout({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['transaction_hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final token = item['token'];
    final contractAddress = token is Map
        ? token['address_hash']?.toString() ?? ''
        : '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final total = item['total'];
    final decimals = total is Map
        ? int.tryParse(total['decimals']?.toString() ?? '') ?? asset.decimals
        : token is Map
        ? int.tryParse(token['decimals']?.toString() ?? '') ?? asset.decimals
        : asset.decimals;
    final rawValue = total is Map
        ? BigInt.tryParse(total['value']?.toString() ?? '')
        : null;
    if (rawValue == null) return null;

    final from = _normalizeEvmDisplayAddress(_blockscoutAddress(item['from']));
    final to = _normalizeEvmDisplayAddress(_blockscoutAddress(item['to']));
    final logIndex = item['log_index']?.toString() ?? '';

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:$logIndex'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
      decimals: decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: WalletTransactionStatus.success,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['timestamp']),
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
    Object? lastError;
    for (final rpcUrl in _evmRpcUrls(chain)) {
      try {
        final response = await dio.post(
          rpcUrl,
          data: {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final data = response.data;
        if (data is Map && data.containsKey('result')) {
          return data['result'];
        }
        throw StateError(data is Map ? data.toString() : 'Invalid RPC data');
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('${chain.name} RPC failed: ${lastError ?? 'unknown'}');
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
    throw StateError('Invalid ${chain.name} $method response');
  }

  Future<List<dynamic>> _evmGetLogs(
    WalletChainRef chain,
    Map<String, dynamic> filter,
  ) async {
    final result = await _evmRpc(chain, 'eth_getLogs', [filter]);
    return result is List ? result : const [];
  }

  WalletTransactionStatus _evmExplorerStatus(Map<dynamic, dynamic> item) {
    if (item['isError']?.toString() == '1' ||
        item['txreceipt_status']?.toString() == '0') {
      return WalletTransactionStatus.failed;
    }
    if (item['txreceipt_status']?.toString() == '1' ||
        item['isError']?.toString() == '0' ||
        !item.containsKey('txreceipt_status')) {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  WalletTransactionStatus _blockscoutStatus(Map<dynamic, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? '';
    final result = item['result']?.toString().toLowerCase() ?? '';
    if (status == 'error' ||
        result.contains('error') ||
        result.contains('fail') ||
        result.contains('out of gas')) {
      return WalletTransactionStatus.failed;
    }
    if (status == 'ok' || result == 'success') {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  String _blockscoutAddress(Object? value) {
    if (value is Map) {
      return value['hash']?.toString() ?? '';
    }
    return value?.toString() ?? '';
  }

  BigInt _blockscoutFeeValue(Map<dynamic, dynamic> item) {
    final fee = item['fee'];
    if (fee is Map) {
      return BigInt.tryParse(fee['value']?.toString() ?? '') ?? BigInt.zero;
    }
    return BigInt.tryParse(fee?.toString() ?? '') ?? BigInt.zero;
  }

  bool _sameEvmAddress(String left, String right) {
    final normalizedLeft = _normalizeEvmCompareAddress(left);
    final normalizedRight = _normalizeEvmCompareAddress(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }

  List<String> _evmRpcUrls(WalletChainRef chain) {
    final fallback = _evmRpcFallbacks[chain.id] ?? const [];
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, fallback);
    }
    return _mergeUrls([chain.rpcUrl], fallback);
  }

  List<_EvmHistoryProvider> _evmHistoryProviders(WalletChainRef chain) {
    final providers = <_EvmHistoryProvider>[];
    final apiKey = _configuredExplorerApiKey(chain);
    final configuredApiUrl = _configuredExplorerApiUrl(chain);

    final canUseEtherscanV2 =
        apiConfig.hasEtherscanApiKey &&
        chain.evmChainId != null &&
        chain.id != WalletChain.bsc.id &&
        chain.id != WalletChain.xLayer.id;
    if (canUseEtherscanV2) {
      developer.log(
        'Using Etherscan V2 history provider for ${chain.name} '
        'chainId=${chain.evmChainId}',
        name: 'WalletTransactionHistoryService',
      );
      providers.add(
        _EvmHistoryProvider(
          url: _etherscanV2ApiUrl,
          apiKey: apiConfig.etherscanApiKey,
          type: _EvmHistoryProviderType.etherscanCompatible,
        ),
      );
    } else if (chain.id == WalletChain.arbitrum.id) {
      developer.log(
        'Etherscan V2 API key is not injected for Arbitrum history',
        name: 'WalletTransactionHistoryService',
      );
    }

    if (configuredApiUrl != null) {
      providers.add(_evmProviderFromUrl(configuredApiUrl, apiKey: apiKey));
    }

    for (final baseUrl in _evmBlockscoutBaseUrls[chain.id] ?? const []) {
      providers.add(
        _EvmHistoryProvider(
          url: baseUrl,
          type: _EvmHistoryProviderType.blockscoutV2,
        ),
      );
    }

    final legacyApiUrl = _evmExplorerApiUrls[chain.id];
    if (legacyApiUrl != null) {
      providers.add(
        _EvmHistoryProvider(
          url: legacyApiUrl,
          apiKey: apiKey,
          type: _EvmHistoryProviderType.etherscanCompatible,
        ),
      );
    }

    final seen = <String>{};
    return providers
        .where((provider) {
          final key = [
            provider.type.name,
            _normalizeExplorerUrl(provider.url),
            provider.apiKey ?? '',
          ].join(':');
          return seen.add(key);
        })
        .toList(growable: false);
  }

  _EvmHistoryProvider _evmProviderFromUrl(String apiUrl, {String? apiKey}) {
    final type = _looksLikeBlockscoutUrl(apiUrl)
        ? _EvmHistoryProviderType.blockscoutV2
        : _EvmHistoryProviderType.etherscanCompatible;
    return _EvmHistoryProvider(url: apiUrl, apiKey: apiKey, type: type);
  }

  String? _configuredExplorerApiUrl(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      final value = chain.explorerApiUrl?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _configuredExplorerApiKey(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      final value = chain.explorerApiKey?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  bool _looksLikeBlockscoutUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.host.toLowerCase().contains('blockscout') ||
        uri.path.toLowerCase().contains('/api/v2');
  }

  String _blockscoutApiBase(String value) {
    final normalized = _normalizeExplorerUrl(value);
    const marker = '/api/v2';
    final markerIndex = normalized.toLowerCase().indexOf(marker);
    if (markerIndex >= 0) {
      return normalized.substring(0, markerIndex + marker.length);
    }
    return '$normalized$marker';
  }

  bool _isEtherscanV2Api(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    return uri.path.toLowerCase().contains('/v2/api');
  }

  String _normalizeExplorerUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }
}

enum _EvmHistoryProviderType { etherscanCompatible, blockscoutV2 }

class _EvmHistoryProvider {
  const _EvmHistoryProvider({
    required this.url,
    required this.type,
    this.apiKey,
  });

  final String url;
  final _EvmHistoryProviderType type;
  final String? apiKey;
}
