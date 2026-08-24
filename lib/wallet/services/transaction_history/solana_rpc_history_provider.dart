part of '../wallet_transaction_history_service.dart';

/// Coordinates Solana RPC history loading without owning transport or parsing.
class _SolanaRpcHistoryClient with _TransactionHistoryProviderHelpers {
  _SolanaRpcHistoryClient({
    required this.dio,
    required this.apiConfig,
    required _SolanaRpcClient rpcClient,
    required _SolanaTokenAccountClient tokenAccountClient,
    required _SolanaTransactionRecordParser parser,
  }) : _rpcClient = rpcClient,
       _tokenAccountClient = tokenAccountClient,
       _parser = parser;

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  final _SolanaRpcClient _rpcClient;
  final _SolanaTokenAccountClient _tokenAccountClient;
  final _SolanaTransactionRecordParser _parser;

  Future<TransactionHistoryPageResult> loadTokenRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final records = await _loadTokenRecords(
      walletId: walletId,
      asset: asset,
      before: cursor?.solanaBefore,
    );
    return TransactionHistoryPageResult(
      records: records,
      nextCursor: records.length >= _SolanaHistoryLimits.historyLimit
          ? TransactionHistoryCursor.solanaBefore(records.last.txHash)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  Future<TransactionHistoryPageResult> loadNativeRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final signatures = await _rpcClient.signaturesForAddress(
      chain: asset.chainRef,
      address: asset.address,
      before: cursor?.solanaBefore,
    );
    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(
      _SolanaHistoryLimits.historyLimit,
    )) {
      final transaction = await _rpcClient.parsedTransaction(
        chain: asset.chainRef,
        signature: signature,
      );
      records.addAll(
        _parser.nativeRecords(
          walletId: walletId,
          asset: asset,
          signature: signature,
          transaction: transaction,
        ),
      );
      if (records.length >= _SolanaHistoryLimits.historyLimit) break;
    }
    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records
          .take(_SolanaHistoryLimits.historyLimit)
          .toList(growable: false),
      nextCursor: signatures.length >= _SolanaHistoryLimits.historyLimit
          ? TransactionHistoryCursor.solanaBefore(signatures.last)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  Future<List<WalletTransactionRecord>> _loadTokenRecords({
    required String walletId,
    required ChainBalance asset,
    String? before,
  }) async {
    final tokenAccounts = await _tokenAccountClient.loadForMint(
      chain: asset.chainRef,
      ownerAddress: asset.address,
      mintAddress: asset.contractAddress ?? '',
    );
    if (tokenAccounts.isEmpty) return const [];

    final signatures = <String>{};
    for (final account in tokenAccounts.take(4)) {
      final accountSignatures = await _rpcClient.signaturesForAddress(
        chain: asset.chainRef,
        address: account,
        limit: math.max(
          8,
          _SolanaHistoryLimits.historyLimit ~/ tokenAccounts.length,
        ),
        before: before,
      );
      signatures.addAll(accountSignatures);
      if (signatures.length >= _SolanaHistoryLimits.historyLimit) break;
    }

    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(
      _SolanaHistoryLimits.historyLimit,
    )) {
      final transaction = await _rpcClient.parsedTransaction(
        chain: asset.chainRef,
        signature: signature,
      );
      records.addAll(
        _parser.tokenRecords(
          walletId: walletId,
          asset: asset,
          signature: signature,
          transaction: transaction,
          ownedTokenAccounts: tokenAccounts.toSet(),
        ),
      );
      if (records.length >= _SolanaHistoryLimits.historyLimit) break;
    }
    records.sort(_compareRecordTimeDesc);
    return records
        .take(_SolanaHistoryLimits.historyLimit)
        .toList(growable: false);
  }
}
