part of '../wallet_transaction_history_service.dart';

class _EvmHistoryCoordinator with _TransactionHistoryProviderHelpers {
  _EvmHistoryCoordinator({required this.dio, required this.apiConfig}) {
    _router = _EvmHistoryProviderRouter(dio: dio, apiConfig: apiConfig);
    _paginator = _EvmHistoryPaginator();
    _parser = _EvmTransactionRecordParser(dio: dio, apiConfig: apiConfig);
    _rpcClient = _EvmRpcHistoryClient(
      dio: dio,
      apiConfig: apiConfig,
      router: _router,
      paginator: _paginator,
      parser: _parser,
    );
    _explorerClient = _EvmExplorerClient(
      dio: dio,
      apiConfig: apiConfig,
      router: _router,
      paginator: _paginator,
      parser: _parser,
      rpcClient: _rpcClient,
    );
  }

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const Duration _limitedLogFallbackTimeout = Duration(seconds: 4);

  late final _EvmHistoryProviderRouter _router;
  late final _EvmHistoryPaginator _paginator;
  late final _EvmTransactionRecordParser _parser;
  late final _EvmRpcHistoryClient _rpcClient;
  late final _EvmExplorerClient _explorerClient;

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
      return _explorerClient.loadTokenLogRecordPage(
        walletId: walletId,
        asset: asset,
        beforeBlock: cursor!.evmLogBeforeBlock!,
      );
    }

    for (final provider in _router.historyProviders(asset.chainRef)) {
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
            await _explorerClient.loadExplorerRecordPage(
              apiUrl: provider.url,
              apiKey: provider.apiKey,
              walletId: walletId,
              asset: asset,
              page: cursor?.evmPage ?? 1,
            ),
          _EvmHistoryProviderType.blockscoutV2 =>
            await _explorerClient.loadBlockscoutRecordPage(
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
        return await _explorerClient.loadTokenLogRecordPage(
          walletId: walletId,
          asset: asset,
        );
      }
      final records = await _rpcClient
          .loadTokenLogs(walletId: walletId, asset: asset)
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
        return _rpcClient.loadNativeRecordByHash(
          walletId: walletId,
          asset: asset,
          txHash: normalizedHash,
        );
      }
      return _rpcClient.loadTokenRecordByHash(
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
}
