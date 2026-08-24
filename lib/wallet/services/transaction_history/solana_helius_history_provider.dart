part of '../wallet_transaction_history_service.dart';

/// Owns Helius paging and delegates enhanced-transaction parsing.
class _SolanaHeliusClient with _TransactionHistoryProviderHelpers {
  _SolanaHeliusClient({
    required this.dio,
    required this.apiConfig,
    required _SolanaHeliusTransactionParser parser,
  }) : _parser = parser;

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  final _SolanaHeliusTransactionParser _parser;

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final records = <WalletTransactionRecord>[];
    String? before = cursor?.solanaBefore;
    String? nextBefore;
    var hasMore = false;

    for (var page = 0; page < _SolanaHistoryLimits.heliusMaxScanPages; page++) {
      final transactions = await _loadTransactions(
        address: asset.address,
        before: before,
      );
      if (transactions.isEmpty) {
        return TransactionHistoryPageResult(
          records: records,
          nextCursor: null,
          emptyReason: records.isEmpty
              ? TransactionHistoryFailureKind.noRecords
              : null,
        );
      }

      for (final transaction in transactions.whereType<Map>()) {
        nextBefore = _solanaHeliusSignature(transaction) ?? nextBefore;
        records.addAll(
          _parser.parse(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
          ),
        );
        if (records.length >= _SolanaHistoryLimits.historyLimit) break;
      }

      nextBefore ??= _solanaHeliusSignature(transactions.last);
      hasMore = transactions.length >= _SolanaHistoryLimits.heliusPageLimit;
      if (records.length >= _SolanaHistoryLimits.historyLimit ||
          !hasMore ||
          nextBefore == null ||
          nextBefore.isEmpty) {
        break;
      }
      before = nextBefore;
    }

    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records
          .take(_SolanaHistoryLimits.historyLimit)
          .toList(growable: false),
      nextCursor: hasMore && nextBefore != null && nextBefore.isNotEmpty
          ? TransactionHistoryCursor.solanaBefore(nextBefore)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  Future<List<dynamic>> _loadTransactions({
    required String address,
    String? before,
  }) async {
    final baseUrl = apiConfig.heliusBaseUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    try {
      final response = await dio.get(
        '$baseUrl/addresses/$address/transactions',
        queryParameters: {
          'api-key': apiConfig.heliusApiKey.trim(),
          'limit': _SolanaHistoryLimits.heliusPageLimit,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final data = response.data;
      if (data is List) return data;
      throw _historyLoadException('Invalid Solana history API response', data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 429) {
        throw const TransactionHistoryLoadException(
          TransactionHistoryFailureKind.rateLimited,
          'Solana history API rate limited',
        );
      }
      throw _historyLoadException('Solana history API request failed', error);
    }
  }
}
