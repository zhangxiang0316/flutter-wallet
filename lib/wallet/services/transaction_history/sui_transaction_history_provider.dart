part of '../wallet_transaction_history_service.dart';

class _SuiTransactionHistoryProvider with _TransactionHistoryProviderHelpers {
  _SuiTransactionHistoryProvider({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  SuiGraphQLClient get _graphql =>
      SuiGraphQLClient.forNetwork(SuiNetwork.mainnet, dio: dio);

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    try {
      final page = await _graphql.queryTransactionsByAddress(
        WalletTransferService.normalizeSuiAddress(asset.address),
        first: _transactionHistoryPageSize,
        after: cursor?.suiGraphqlCursor,
      );
      final records =
          page.transactions
              .map((transaction) {
                return _recordFromTransaction(
                  walletId: walletId,
                  asset: asset,
                  transaction: transaction,
                );
              })
              .whereType<WalletTransactionRecord>()
              .toList(growable: false)
            ..sort(_compareRecordTimeDesc);
      return TransactionHistoryPageResult(
        records: records,
        nextCursor: page.hasNextPage && page.endCursor != null
            ? TransactionHistoryCursor.suiGraphqlCursor(page.endCursor!)
            : null,
        emptyReason: records.isEmpty
            ? TransactionHistoryFailureKind.noRecords
            : null,
      );
    } catch (error) {
      throw _historyLoadException('Sui history provider failed', error);
    }
  }

  Future<WalletTransactionRecord?> loadRecordByTransactionHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final normalizedHash = txHash.trim();
    if (normalizedHash.isEmpty) return null;
    final firstPage = await loadRecordPage(walletId: walletId, asset: asset);
    for (final record in firstPage.records) {
      if (record.txHash == normalizedHash) return record;
    }
    return null;
  }

  WalletTransactionRecord? _recordFromTransaction({
    required String walletId,
    required ChainBalance asset,
    required SenderTransaction transaction,
  }) {
    final walletAddress = asset.address.trim().toLowerCase();
    final coinType = asset.isNative
        ? _normalizeCoinType('0x2::sui::SUI')
        : _normalizeCoinType(asset.contractAddress ?? '');
    final matchingChanges = transaction.balanceChanges
        .where((change) => _normalizeCoinType(change.coinType) == coinType)
        .toList(growable: false);
    TxBalanceChange? walletChange;
    for (final change in matchingChanges) {
      if (change.ownerAddress?.trim().toLowerCase() == walletAddress) {
        walletChange = change;
        break;
      }
    }
    if (walletChange == null) return null;

    final signedAmount = BigInt.tryParse(walletChange.amount) ?? BigInt.zero;
    if (signedAmount == BigInt.zero) return null;
    final direction = signedAmount > BigInt.zero
        ? WalletTransactionDirection.incoming
        : WalletTransactionDirection.outgoing;
    var counterparty = '';
    var counterpartyAmount = BigInt.zero;
    for (final change in matchingChanges) {
      final owner = change.ownerAddress?.trim() ?? '';
      final value = BigInt.tryParse(change.amount) ?? BigInt.zero;
      if (owner.isNotEmpty &&
          owner.toLowerCase() != walletAddress &&
          value.sign != signedAmount.sign) {
        counterparty = counterparty.isEmpty ? owner : counterparty;
        counterpartyAmount += value.abs();
      }
    }
    // SUI 的发送方余额变化同时包含转账金额和 gas。优先用收款方增量作为
    // 实际转账金额，避免把手续费算入资产金额。
    final displayAmount =
        direction == WalletTransactionDirection.outgoing &&
            counterpartyAmount > BigInt.zero
        ? counterpartyAmount
        : signedAmount.abs();
    final feeRaw = _suiFeeRaw(transaction, walletAddress);

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, transaction.digest),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: transaction.digest,
      fromAddress: direction == WalletTransactionDirection.outgoing
          ? asset.address
          : counterparty,
      toAddress: direction == WalletTransactionDirection.incoming
          ? asset.address
          : counterparty,
      amount: WalletTransferService.rawUnitsToAmount(
        displayAmount,
        asset.decimals,
      ),
      decimals: asset.decimals,
      direction: direction,
      status: transaction.success
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeSymbol: 'SUI',
      feeAmount: feeRaw > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(feeRaw, 9)
          : null,
      timestamp: transaction.timestampMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(transaction.timestampMs!),
    );
  }

  BigInt _suiFeeRaw(SenderTransaction transaction, String walletAddress) {
    final nativeType = _normalizeCoinType('0x2::sui::SUI');
    var walletDebit = BigInt.zero;
    var creditedElsewhere = BigInt.zero;
    for (final change in transaction.balanceChanges) {
      if (_normalizeCoinType(change.coinType) != nativeType) continue;
      final owner = change.ownerAddress?.trim().toLowerCase() ?? '';
      final value = BigInt.tryParse(change.amount) ?? BigInt.zero;
      if (owner == walletAddress && value < BigInt.zero) {
        walletDebit += value.abs();
      } else if (owner.isNotEmpty &&
          owner != walletAddress &&
          value > BigInt.zero) {
        creditedElsewhere += value;
      }
    }
    final fee = walletDebit - creditedElsewhere;
    return fee > BigInt.zero ? fee : BigInt.zero;
  }

  String _normalizeCoinType(String value) {
    final parts = value.trim().toLowerCase().split('::');
    if (parts.length < 3) return value.trim().toLowerCase();
    final address = parts.first.replaceFirst(RegExp(r'^0x0*'), '0x');
    return [address == '0x' ? '0x0' : address, ...parts.skip(1)].join('::');
  }
}
