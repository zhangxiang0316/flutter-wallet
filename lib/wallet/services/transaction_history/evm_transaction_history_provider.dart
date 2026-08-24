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
}
