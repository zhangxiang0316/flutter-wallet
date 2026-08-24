part of '../wallet_transaction_history_service.dart';

class _SolanaHistoryLimits {
  static const int historyLimit = _transactionHistoryPageSize;
  static const int heliusPageLimit = 50;
  static const int heliusMaxScanPages = 3;
}

class _SolanaHistoryCoordinator with _TransactionHistoryProviderHelpers {
  _SolanaHistoryCoordinator({required this.dio, required this.apiConfig}) {
    final rpcClient = _SolanaRpcClient(dio: dio, apiConfig: apiConfig);
    final recordParser = _SolanaTransactionRecordParser(
      dio: dio,
      apiConfig: apiConfig,
    );
    _heliusClient = _SolanaHeliusClient(
      dio: dio,
      apiConfig: apiConfig,
      parser: _SolanaHeliusTransactionParser(dio: dio, apiConfig: apiConfig),
    );
    _rpcHistoryClient = _SolanaRpcHistoryClient(
      dio: dio,
      apiConfig: apiConfig,
      rpcClient: rpcClient,
      tokenAccountClient: _SolanaTokenAccountClient(
        dio: dio,
        apiConfig: apiConfig,
        rpcClient: rpcClient,
      ),
      parser: recordParser,
    );
  }

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  late final _SolanaHeliusClient _heliusClient;
  late final _SolanaRpcHistoryClient _rpcHistoryClient;

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? heliusError;
    if (apiConfig.hasHeliusApiKey) {
      try {
        return await _heliusClient.loadRecordPage(
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
        return await _rpcHistoryClient.loadNativeRecordPage(
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
      return await _rpcHistoryClient.loadTokenRecordPage(
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
