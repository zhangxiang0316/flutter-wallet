part of '../wallet_transaction_history_service.dart';

class _BitcoinTransactionHistoryProvider
    with _TransactionHistoryProviderHelpers {
  _BitcoinTransactionHistoryProvider({
    required this.dio,
    required this.apiConfig,
  });

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const int _esploraPageSize = 25;

  static const List<String> _bitcoinApiFallbacks = [
    'https://mempool.space/api',
    'https://blockstream.info/api',
  ];

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    Object? lastError;
    for (final apiUrl in _bitcoinApiUrls(asset.chainRef)) {
      try {
        final lastSeen = cursor?.bitcoinLastSeenTxId;
        final path = lastSeen == null || lastSeen.isEmpty
            ? '$apiUrl/address/${asset.address}/txs'
            : '$apiUrl/address/${asset.address}/txs/chain/$lastSeen';
        final response = await dio.get(path);
        final values = response.data;
        if (values is! List) {
          throw _historyLoadException(
            'Invalid Bitcoin history response',
            values,
          );
        }
        final records =
            values
                .whereType<Map>()
                .map(
                  (item) => _bitcoinRecord(
                    walletId: walletId,
                    asset: asset,
                    item: item,
                  ),
                )
                .whereType<WalletTransactionRecord>()
                .toList(growable: false)
              ..sort(_compareRecordTimeDesc);
        final nextTxId = values.length >= _esploraPageSize && values.last is Map
            ? (values.last as Map)['txid']?.toString()
            : null;
        return TransactionHistoryPageResult(
          records: records,
          nextCursor: nextTxId == null || nextTxId.isEmpty
              ? null
              : TransactionHistoryCursor.bitcoinLastSeenTxId(nextTxId),
          emptyReason: records.isEmpty
              ? TransactionHistoryFailureKind.noRecords
              : null,
        );
      } catch (error) {
        lastError = error;
        SafeLog.error(
          'Bitcoin history request failed at $apiUrl: $error',
          name: 'WalletTransactionHistoryService',
        );
      }
    }
    throw _historyLoadException('Bitcoin history failed', lastError);
  }

  Future<WalletTransactionRecord?> loadRecordByTransactionHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    Object? lastError;
    for (final apiUrl in _bitcoinApiUrls(asset.chainRef)) {
      try {
        final response = await dio.get('$apiUrl/tx/$txHash');
        final data = response.data;
        if (data is! Map) {
          throw _historyLoadException('Invalid Bitcoin transaction', data);
        }
        return _bitcoinRecord(walletId: walletId, asset: asset, item: data);
      } catch (error) {
        lastError = error;
      }
    }
    throw _historyLoadException('Bitcoin transaction lookup failed', lastError);
  }

  WalletTransactionRecord? _bitcoinRecord({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['txid']?.toString() ?? '';
    if (txHash.isEmpty) return null;
    final walletAddress = asset.address.trim().toLowerCase();
    final inputs = item['vin'] is List ? item['vin'] as List : const [];
    final outputs = item['vout'] is List ? item['vout'] as List : const [];
    final walletInputSats = inputs.fold<BigInt>(BigInt.zero, (total, input) {
      if (input is! Map) return total;
      final previousOutput = input['prevout'];
      if (previousOutput is! Map ||
          _bitcoinOutputAddress(previousOutput) != walletAddress) {
        return total;
      }
      return total + _bitcoinValue(previousOutput['value']);
    });
    final walletOutputSats = outputs.fold<BigInt>(BigInt.zero, (total, output) {
      if (output is! Map || _bitcoinOutputAddress(output) != walletAddress) {
        return total;
      }
      return total + _bitcoinValue(output['value']);
    });
    final externalOutputs = outputs.whereType<Map>().where(
      (output) => _bitcoinOutputAddress(output) != walletAddress,
    );
    final externalOutputSats = externalOutputs.fold<BigInt>(
      BigInt.zero,
      (total, output) => total + _bitcoinValue(output['value']),
    );
    final direction = walletInputSats > BigInt.zero
        ? externalOutputSats > BigInt.zero
              ? WalletTransactionDirection.outgoing
              : WalletTransactionDirection.selfTransfer
        : walletOutputSats > BigInt.zero
        ? WalletTransactionDirection.incoming
        : WalletTransactionDirection.unknown;
    final amountSats = switch (direction) {
      WalletTransactionDirection.outgoing => externalOutputSats,
      WalletTransactionDirection.selfTransfer => walletOutputSats,
      WalletTransactionDirection.incoming => walletOutputSats,
      WalletTransactionDirection.unknown => BigInt.zero,
    };
    final firstInputAddress = inputs
        .whereType<Map>()
        .map((input) {
          final previousOutput = input['prevout'];
          return previousOutput is Map
              ? _bitcoinOutputAddress(previousOutput)
              : '';
        })
        .firstWhere((address) => address.isNotEmpty, orElse: () => '');
    final firstExternalAddress = externalOutputs
        .map(_bitcoinOutputAddress)
        .firstWhere((address) => address.isNotEmpty, orElse: () => '');
    final status = item['status'];
    final confirmed = status is Map && status['confirmed'] == true;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: firstInputAddress,
      toAddress: direction == WalletTransactionDirection.incoming
          ? asset.address
          : firstExternalAddress,
      amount: WalletTransferService.rawUnitsToAmount(
        amountSats,
        asset.decimals,
      ),
      decimals: asset.decimals,
      direction: direction,
      status: confirmed
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.pending,
      source: WalletTransactionSource.remote,
      feeAmount: WalletTransferService.rawUnitsToAmount(
        _bitcoinValue(item['fee']),
        asset.decimals,
      ),
      feeSymbol: 'BTC',
      blockNumber: status is Map
          ? int.tryParse(status['block_height']?.toString() ?? '')
          : null,
      timestamp: status is Map
          ? _dateTimeFromSeconds(status['block_time'])
          : null,
    );
  }

  List<String> _bitcoinApiUrls(WalletChainRef chain) {
    final primary = chain is WalletChainConfig ? chain.rpcUrls : [chain.rpcUrl];
    return _mergeUrls(primary, _bitcoinApiFallbacks);
  }

  String _bitcoinOutputAddress(Map<dynamic, dynamic> output) {
    return output['scriptpubkey_address']?.toString().trim().toLowerCase() ??
        '';
  }

  BigInt _bitcoinValue(Object? value) {
    return BigInt.tryParse(value?.toString() ?? '') ?? BigInt.zero;
  }
}
