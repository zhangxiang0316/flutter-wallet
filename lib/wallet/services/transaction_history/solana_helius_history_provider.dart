part of '../wallet_transaction_history_service.dart';

extension _SolanaHeliusHistoryProvider on _SolanaTransactionHistoryProvider {
  Future<TransactionHistoryPageResult> _loadSolanaHeliusRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final records = <WalletTransactionRecord>[];
    String? before = cursor?.solanaBefore;
    String? nextBefore;
    var hasMore = false;

    for (
      var page = 0;
      page < _SolanaTransactionHistoryProvider._heliusMaxScanPages;
      page++
    ) {
      final transactions = await _solanaHeliusTransactions(
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
          _solanaHeliusRecordsFromTransaction(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
          ),
        );
        if (records.length >= _SolanaTransactionHistoryProvider._historyLimit) {
          break;
        }
      }

      nextBefore ??= _solanaHeliusSignature(transactions.last);
      hasMore =
          transactions.length >=
          _SolanaTransactionHistoryProvider._heliusPageLimit;
      if (records.length >= _SolanaTransactionHistoryProvider._historyLimit ||
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
          .take(_SolanaTransactionHistoryProvider._historyLimit)
          .toList(growable: false),
      nextCursor: hasMore && nextBefore != null && nextBefore.isNotEmpty
          ? TransactionHistoryCursor.solanaBefore(nextBefore)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
          : null,
    );
  }

  Future<List<dynamic>> _solanaHeliusTransactions({
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
          'limit': _SolanaTransactionHistoryProvider._heliusPageLimit,
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

  List<WalletTransactionRecord> _solanaHeliusRecordsFromTransaction({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> transaction,
  }) {
    return asset.isNative
        ? _solanaHeliusNativeRecordsFromTransaction(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
          )
        : _solanaHeliusTokenRecordsFromTransaction(
            walletId: walletId,
            asset: asset,
            transaction: transaction,
          );
  }

  List<WalletTransactionRecord> _solanaHeliusNativeRecordsFromTransaction({
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
        _solanaRecord(
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
    return _solanaHeliusNativeBalanceRecordsFromTransaction(
      walletId: walletId,
      asset: asset,
      transaction: transaction,
    );
  }

  List<WalletTransactionRecord> _solanaHeliusTokenRecordsFromTransaction({
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
        _solanaRecord(
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
    return _solanaHeliusTokenBalanceRecordsFromTransaction(
      walletId: walletId,
      asset: asset,
      transaction: transaction,
    );
  }

  List<WalletTransactionRecord>
  _solanaHeliusNativeBalanceRecordsFromTransaction({
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
        _solanaRecord(
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

  List<WalletTransactionRecord>
  _solanaHeliusTokenBalanceRecordsFromTransaction({
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
        records.add(
          _solanaRecord(
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
              _solanaHeliusTokenChangeDecimals(change, asset.decimals),
            ),
            decimals: _solanaHeliusTokenChangeDecimals(change, asset.decimals),
            direction: direction,
          ),
        );
      }
    }
    return records;
  }

  WalletTransactionRecord _solanaRecord({
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
