part of '../wallet_transaction_history_service.dart';

/// Converts Helius enhanced transactions into wallet transaction records.
class _SolanaHeliusTransactionParser with _TransactionHistoryProviderHelpers {
  _SolanaHeliusTransactionParser({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  List<WalletTransactionRecord> parse({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
  }) {
    return asset.isNative
        ? _nativeRecords(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
          )
        : _tokenRecords(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
          );
  }

  List<WalletTransactionRecord> _nativeRecords({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
  }) {
    final transfers = transaction['nativeTransfers'];
    if (transfers is! List) return const [];
    final records = <WalletTransactionRecord>[];
    for (var index = 0; index < transfers.length; index++) {
      final transfer = transfers[index];
      if (transfer is! Map) continue;
      final from = transfer['fromUserAccount']?.toString() ?? '';
      final to = transfer['toUserAccount']?.toString() ?? '';
      if (from != asset.address && to != asset.address) continue;
      final lamports =
          BigInt.tryParse(transfer['amount']?.toString() ?? '') ?? BigInt.zero;
      if (lamports == BigInt.zero) continue;
      records.add(
        _record(
          walletId: walletId,
          asset: asset,
          transaction: transaction,
          index: index,
          from: from,
          to: to,
          amount: WalletTransferService.rawUnitsToAmount(lamports, 9),
          decimals: 9,
          direction: _directionForAddress(
            walletAddress: asset.address,
            fromAddress: from,
            toAddress: to,
            normalize: (value) => value.trim(),
          ),
        ),
      );
    }
    if (records.isNotEmpty) return records;
    return _nativeBalanceRecords(
      walletId: walletId,
      asset: asset,
      transaction: transaction,
    );
  }

  List<WalletTransactionRecord> _tokenRecords({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
  }) {
    final transfers = transaction['tokenTransfers'];
    if (transfers is! List) return const [];
    final mint = asset.contractAddress?.trim() ?? '';
    final records = <WalletTransactionRecord>[];
    for (var index = 0; index < transfers.length; index++) {
      final transfer = transfers[index];
      if (transfer is! Map) continue;
      if (mint.isNotEmpty && transfer['mint']?.toString() != mint) continue;
      final from = transfer['fromUserAccount']?.toString() ?? '';
      final to = transfer['toUserAccount']?.toString() ?? '';
      if (from != asset.address && to != asset.address) continue;
      final amount = _solanaHeliusTokenAmount(transfer, asset.decimals);
      if (amount == null) continue;
      records.add(
        _record(
          walletId: walletId,
          asset: asset,
          transaction: transaction,
          index: index,
          from: from,
          to: to,
          amount: amount,
          decimals: asset.decimals,
          direction: _directionForAddress(
            walletAddress: asset.address,
            fromAddress: from,
            toAddress: to,
            normalize: (value) => value.trim(),
          ),
        ),
      );
    }
    if (records.isNotEmpty) return records;
    return _tokenBalanceRecords(
      walletId: walletId,
      asset: asset,
      transaction: transaction,
    );
  }

  List<WalletTransactionRecord> _nativeBalanceRecords({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
  }) {
    final accountData = transaction['accountData'];
    if (accountData is! List) return const [];
    final records = <WalletTransactionRecord>[];
    for (var index = 0; index < accountData.length; index++) {
      final item = accountData[index];
      if (item is! Map || item['account']?.toString() != asset.address) {
        continue;
      }
      final change =
          BigInt.tryParse(item['nativeBalanceChange']?.toString() ?? '') ??
          BigInt.zero;
      if (change == BigInt.zero) continue;
      final direction = change > BigInt.zero
          ? WalletTransactionDirection.incoming
          : WalletTransactionDirection.outgoing;
      records.add(
        _record(
          walletId: walletId,
          asset: asset,
          transaction: transaction,
          index: index,
          from: direction == WalletTransactionDirection.outgoing
              ? asset.address
              : '',
          to: direction == WalletTransactionDirection.incoming
              ? asset.address
              : '',
          amount: WalletTransferService.rawUnitsToAmount(change.abs(), 9),
          decimals: 9,
          direction: direction,
        ),
      );
    }
    return records;
  }

  List<WalletTransactionRecord> _tokenBalanceRecords({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
  }) {
    final accountData = transaction['accountData'];
    if (accountData is! List) return const [];
    final mint = asset.contractAddress?.trim() ?? '';
    final records = <WalletTransactionRecord>[];
    for (
      var accountIndex = 0;
      accountIndex < accountData.length;
      accountIndex++
    ) {
      final item = accountData[accountIndex];
      if (item is! Map) continue;
      final changes = item['tokenBalanceChanges'];
      if (changes is! List) continue;
      for (var changeIndex = 0; changeIndex < changes.length; changeIndex++) {
        final change = changes[changeIndex];
        if (change is! Map) continue;
        if (mint.isNotEmpty && change['mint']?.toString() != mint) continue;
        if (!_solanaHeliusTokenChangeTouchesWallet(change, asset.address)) {
          continue;
        }
        final amount = _solanaHeliusSignedTokenRawAmount(
          change,
          asset.decimals,
        );
        if (amount == null || amount == BigInt.zero) continue;
        final direction = amount > BigInt.zero
            ? WalletTransactionDirection.incoming
            : WalletTransactionDirection.outgoing;
        final decimals = _solanaHeliusTokenChangeDecimals(
          change,
          asset.decimals,
        );
        records.add(
          _record(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
            index: accountIndex * 1000 + changeIndex,
            from: direction == WalletTransactionDirection.outgoing
                ? asset.address
                : '',
            to: direction == WalletTransactionDirection.incoming
                ? asset.address
                : '',
            amount: WalletTransferService.rawUnitsToAmount(
              amount.abs(),
              decimals,
            ),
            decimals: decimals,
            direction: direction,
          ),
        );
      }
    }
    return records;
  }

  WalletTransactionRecord _record({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
    required int index,
    required String from,
    required String to,
    required String amount,
    required int decimals,
    required WalletTransactionDirection direction,
  }) {
    final signature = _solanaHeliusSignature(transaction) ?? '';
    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$signature:$index'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: signature,
      fromAddress: from,
      toAddress: to,
      amount: amount,
      decimals: decimals,
      direction: direction,
      status: transaction['transactionError'] == null
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeAmount: _solanaHeliusFeeAmount(transaction),
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(transaction['slot']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(transaction['timestamp']),
    );
  }
}
