part of '../wallet_transaction_history_service.dart';

class _SolanaTransactionHistoryProvider
    with _TransactionHistoryProviderHelpers {
  _SolanaTransactionHistoryProvider({
    required this.dio,
    required this.apiConfig,
  });

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const int _historyLimit = _transactionHistoryPageSize;
  static const int _heliusPageLimit = 50;
  static const int _heliusMaxScanPages = 3;

  static const List<String> _solanaRpcFallbacks = [
    'https://api.mainnet-beta.solana.com',
    'https://solana-rpc.publicnode.com',
  ];

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? heliusError;
    if (apiConfig.hasHeliusApiKey) {
      try {
        return await _loadSolanaHeliusRecordPage(
          walletId: walletId,
          asset: asset,
          cursor: cursor,
        );
      } catch (error) {
        heliusError = error;
        SafeLog.error(
          'Solana Helius history failed: $error',
          name: 'WalletTransactionHistoryService',
        );
        if (error is TransactionHistoryLoadException &&
            (error.kind == TransactionHistoryFailureKind.rateLimited ||
                error.kind == TransactionHistoryFailureKind.apiKeyInvalid)) {
          rethrow;
        }
      }
    }

    if (asset.isNative) {
      try {
        return await _loadSolanaNativeRecordPage(
          walletId: walletId,
          asset: asset,
          cursor: cursor,
        );
      } catch (error) {
        throw _historyLoadException(
          'Solana history provider failed',
          heliusError ?? error,
        );
      }
    }
    try {
      return await _loadSolanaTokenRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    } catch (error) {
      throw _historyLoadException(
        'Solana token history provider failed',
        heliusError ?? error,
      );
    }
  }
}
