part of '../wallet_transaction_history_service.dart';

class _EvmExplorerClient with _TransactionHistoryProviderHelpers {
  _EvmExplorerClient({
    required this.dio,
    required this.apiConfig,
    required _EvmHistoryProviderRouter router,
    required _EvmHistoryPaginator paginator,
    required _EvmTransactionRecordParser parser,
    required _EvmRpcHistoryClient rpcClient,
  }) : _router = router,
       _paginator = paginator,
       _parser = parser,
       _rpcClient = rpcClient;

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  final _EvmHistoryProviderRouter _router;
  final _EvmHistoryPaginator _paginator;
  final _EvmTransactionRecordParser _parser;
  final _EvmRpcHistoryClient _rpcClient;

  Future<TransactionHistoryPageResult> loadTokenLogRecordPage({
    required String walletId,
    required ChainBalance asset,
    int? beforeBlock,
  }) async {
    final latestBlock = beforeBlock == null
        ? await _rpcClient.rpcBigInt(
            asset.chainRef,
            'eth_blockNumber',
            const [],
          )
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
      toBlock - _paginator.logPageBlockWindow(asset.chainRef) + 1,
    );
    final records = await _rpcClient.loadTokenLogsInRange(
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

  Future<TransactionHistoryPageResult> loadExplorerRecordPage({
    required String apiUrl,
    String? apiKey,
    required String walletId,
    required ChainBalance asset,
    required int page,
  }) async {
    final requestLimit = _paginator.explorerRequestLimit(asset.chainRef);
    final maxScanPages = _paginator.explorerScanPages(asset.chainRef);
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
          if (_router.isEtherscanV2Api(apiUrl) &&
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
        for (final item in result.whereType<Map>()) {
          final txHash = item['hash']?.toString().toLowerCase() ?? '';
          final transferIndex = asset.isNative || txHash.isEmpty
              ? null
              : transferCountsByHash
                    .update(txHash, (count) => count + 1, ifAbsent: () => 0)
                    .toString();
          final record = asset.isNative
              ? _parser.nativeRecordFromExplorer(
                  walletId: walletId,
                  asset: asset,
                  item: item,
                )
              : _parser.tokenRecordFromExplorer(
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
        if (records.length >= _EvmHistoryPaginator.historyLimit ||
            !hasMoreRawPages) {
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
      records: records
          .take(_EvmHistoryPaginator.historyLimit)
          .toList(growable: false),
      nextCursor: hasMoreRawPages
          ? TransactionHistoryCursor.evmExplorerPage(currentPage + 1)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  Future<TransactionHistoryPageResult> loadBlockscoutRecordPage({
    required String baseUrl,
    required String walletId,
    required ChainBalance asset,
    String? cursor,
  }) async {
    final apiBase = _router.blockscoutApiBase(baseUrl);
    final path = asset.isNative ? 'transactions' : 'token-transfers';
    var queryParameters =
        _parser.decodeBlockscoutCursor(cursor) ??
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

    for (var page = 0; page < _EvmHistoryPaginator.blockscoutMaxPages; page++) {
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
            ? _parser.nativeRecordFromBlockscout(
                walletId: walletId,
                asset: asset,
                item: item,
              )
            : _parser.tokenRecordFromBlockscout(
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
      if (records.length >= _EvmHistoryPaginator.historyLimit) {
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
      records: records
          .take(_EvmHistoryPaginator.historyLimit)
          .toList(growable: false),
      nextCursor: nextCursor,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }
}
