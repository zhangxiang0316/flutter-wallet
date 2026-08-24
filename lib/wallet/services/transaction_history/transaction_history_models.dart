part of '../wallet_transaction_history_service.dart';

const int _transactionHistoryPageSize = 10;

enum TransactionHistoryFailureKind {
  noRecords,
  rateLimited,
  apiKeyMissing,
  apiKeyInvalid,
  timeout,
  providerFailed,
}

class TransactionHistoryLoadException implements Exception {
  const TransactionHistoryLoadException(this.kind, this.message, [this.cause]);

  final TransactionHistoryFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// 交易历史分页游标。
class TransactionHistoryCursor {
  const TransactionHistoryCursor._(this.source, this.value);

  const TransactionHistoryCursor.evmExplorerPage(int page)
    : this._('evmExplorerPage', page);

  const TransactionHistoryCursor.evmLogBeforeBlock(int block)
    : this._('evmLogBeforeBlock', block);

  const TransactionHistoryCursor.blockscoutPage(String value)
    : this._('blockscoutPage', value);

  const TransactionHistoryCursor.moralisCursor(String value)
    : this._('moralisCursor', value);

  const TransactionHistoryCursor.tronFingerprint(String value)
    : this._('tronFingerprint', value);

  const TransactionHistoryCursor.solanaBefore(String value)
    : this._('solanaBefore', value);

  const TransactionHistoryCursor.bitcoinLastSeenTxId(String value)
    : this._('bitcoinLastSeenTxId', value);

  const TransactionHistoryCursor.suiGraphqlCursor(String value)
    : this._('suiGraphqlCursor', value);

  const TransactionHistoryCursor.aptosOffset(int value)
    : this._('aptosOffset', value);

  /// 游标来源。
  final String source;

  /// 来源特定的下一页参数。
  final Object value;

  int? get evmPage => source == 'evmExplorerPage' ? value as int : null;

  int? get evmLogBeforeBlock =>
      source == 'evmLogBeforeBlock' ? value as int : null;

  String? get blockscoutParams =>
      source == 'blockscoutPage' ? value as String : null;

  String? get moralisCursor =>
      source == 'moralisCursor' ? value as String : null;

  String? get tronFingerprint =>
      source == 'tronFingerprint' ? value as String : null;

  String? get solanaBefore => source == 'solanaBefore' ? value as String : null;

  String? get bitcoinLastSeenTxId =>
      source == 'bitcoinLastSeenTxId' ? value as String : null;

  String? get suiGraphqlCursor =>
      source == 'suiGraphqlCursor' ? value as String : null;

  int? get aptosOffset => source == 'aptosOffset' ? value as int : null;
}

/// 交易历史分页结果。
class TransactionHistoryPageResult {
  const TransactionHistoryPageResult({
    required this.records,
    required this.nextCursor,
    this.emptyReason,
  });

  /// 当前页交易记录。
  final List<WalletTransactionRecord> records;

  /// 下一页游标；为 null 表示当前数据源没有更多可取记录。
  final TransactionHistoryCursor? nextCursor;

  /// 空列表原因；仅在成功请求但没有记录时使用。
  final TransactionHistoryFailureKind? emptyReason;

  bool get hasMore => nextCursor != null;
}
