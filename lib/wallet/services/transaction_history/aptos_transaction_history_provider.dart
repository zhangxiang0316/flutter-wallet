part of '../wallet_transaction_history_service.dart';

/// Aptos Indexer-backed APT and fungible-asset transaction history.
class _AptosTransactionHistoryProvider with _TransactionHistoryProviderHelpers {
  _AptosTransactionHistoryProvider({
    required this.dio,
    required this.apiConfig,
  });

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  static const String _indexerUrl =
      'https://api.mainnet.aptoslabs.com/v1/graphql';

  static const String _activityQuery = r'''
query WalletAptosActivities(
  $where: fungible_asset_activities_bool_exp!
  $offset: Int!
  $limit: Int!
) {
  fungible_asset_activities(
    where: $where
    order_by: [{transaction_version: desc}, {event_index: desc}]
    offset: $offset
    limit: $limit
  ) {
    amount
    asset_type
    block_height
    event_index
    is_gas_fee
    is_transaction_success
    owner_address
    transaction_timestamp
    transaction_version
    type
  }
}
''';

  static const String _counterpartyQuery = r'''
query WalletAptosCounterparties(
  $where: fungible_asset_activities_bool_exp!
) {
  fungible_asset_activities(
    where: $where
    order_by: [{transaction_version: desc}, {event_index: desc}]
  ) {
    amount
    owner_address
    transaction_version
    type
  }
}
''';

  Future<TransactionHistoryPageResult> loadRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    try {
      final offset = cursor?.aptosOffset ?? 0;
      final walletAddress = WalletTransferService.normalizeAptosAddress(
        asset.address,
      );
      final assetType = _assetType(asset);
      final activities = await _queryActivities(
        where: {
          'owner_address': {'_eq': walletAddress},
          'asset_type': {'_eq': assetType},
          'is_gas_fee': {'_eq': false},
        },
        offset: offset,
        limit: _transactionHistoryPageSize,
      );
      if (activities.isEmpty) {
        return const TransactionHistoryPageResult(
          records: [],
          nextCursor: null,
          emptyReason: TransactionHistoryFailureKind.noRecords,
        );
      }

      final versions = activities
          .map((item) => item['transaction_version']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final counterparties = await _queryCounterparties(
        versions: versions,
        assetType: assetType,
      );
      final transactions = await _loadTransactionsByVersion(
        asset.chainRef,
        versions,
      );

      final records =
          activities
              .map(
                (activity) => _recordFromActivity(
                  walletId: walletId,
                  asset: asset,
                  activity: activity,
                  counterparties: counterparties,
                  transactions: transactions,
                ),
              )
              .whereType<WalletTransactionRecord>()
              .toList(growable: false)
            ..sort(_compareRecordTimeDesc);
      return TransactionHistoryPageResult(
        records: records,
        nextCursor: activities.length == _transactionHistoryPageSize
            ? TransactionHistoryCursor.aptosOffset(offset + activities.length)
            : null,
        emptyReason: records.isEmpty
            ? TransactionHistoryFailureKind.noRecords
            : null,
      );
    } catch (error) {
      throw _historyLoadException('Aptos history provider failed', error);
    }
  }

  Future<WalletTransactionRecord?> loadRecordByTransactionHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final hash = txHash.trim().toLowerCase();
    if (hash.isEmpty) return null;
    final page = await loadRecordPage(walletId: walletId, asset: asset);
    for (final record in page.records) {
      if (record.txHash.toLowerCase() == hash) return record;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _queryActivities({
    required Map<String, dynamic> where,
    required int offset,
    required int limit,
  }) async {
    final response = await dio.post(
      _indexerUrl,
      data: {
        'query': _activityQuery,
        'variables': {'where': where, 'offset': offset, 'limit': limit},
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    return _graphqlRows(response.data);
  }

  Future<List<Map<String, dynamic>>> _queryCounterparties({
    required List<String> versions,
    required String assetType,
  }) async {
    if (versions.isEmpty) return const [];
    final response = await dio.post(
      _indexerUrl,
      data: {
        'query': _counterpartyQuery,
        'variables': {
          'where': {
            'transaction_version': {'_in': versions},
            'asset_type': {'_eq': assetType},
            'is_gas_fee': {'_eq': false},
          },
        },
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    return _graphqlRows(response.data);
  }

  List<Map<String, dynamic>> _graphqlRows(Object? responseData) {
    if (responseData is! Map) {
      throw StateError('Invalid Aptos Indexer response');
    }
    final errors = responseData['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw StateError('Aptos Indexer error: $errors');
    }
    final data = responseData['data'];
    final rows = data is Map ? data['fungible_asset_activities'] : null;
    if (rows is! List) {
      throw StateError('Invalid Aptos activity response');
    }
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _loadTransactionsByVersion(
    WalletChainRef chain,
    List<String> versions,
  ) async {
    final entries = await Future.wait(
      versions.map((version) async {
        try {
          final response = await dio.get(
            '${chain.rpcUrl}/transactions/by_version/$version',
          );
          final data = response.data;
          return MapEntry(
            version,
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
          );
        } catch (_) {
          return MapEntry(version, <String, dynamic>{});
        }
      }),
    );
    return Map<String, Map<String, dynamic>>.fromEntries(entries);
  }

  WalletTransactionRecord? _recordFromActivity({
    required String walletId,
    required ChainBalance asset,
    required Map<String, dynamic> activity,
    required List<Map<String, dynamic>> counterparties,
    required Map<String, Map<String, dynamic>> transactions,
  }) {
    final version = activity['transaction_version']?.toString() ?? '';
    if (version.isEmpty) return null;
    final rawAmount = BigInt.tryParse(activity['amount']?.toString() ?? '');
    if (rawAmount == null || rawAmount == BigInt.zero) return null;
    final type = activity['type']?.toString().toLowerCase() ?? '';
    final direction = type.contains('deposit')
        ? WalletTransactionDirection.incoming
        : type.contains('withdraw')
        ? WalletTransactionDirection.outgoing
        : WalletTransactionDirection.unknown;
    if (direction == WalletTransactionDirection.unknown) return null;

    final walletAddress = WalletTransferService.normalizeAptosAddress(
      asset.address,
    );
    final transaction = transactions[version] ?? const <String, dynamic>{};
    final hash = transaction['hash']?.toString() ?? version;
    final counterparty = _counterpartyFor(
      activity: activity,
      activities: counterparties,
      walletAddress: walletAddress,
      direction: direction,
    );
    final sender = transaction['sender']?.toString() ?? '';
    final fallbackRecipient = _recipientFromPayload(transaction['payload']);
    final fromAddress = direction == WalletTransactionDirection.outgoing
        ? walletAddress
        : (counterparty.isNotEmpty ? counterparty : sender);
    final toAddress = direction == WalletTransactionDirection.incoming
        ? walletAddress
        : (counterparty.isNotEmpty ? counterparty : fallbackRecipient);
    final gasUsed = BigInt.tryParse(transaction['gas_used']?.toString() ?? '');
    final gasPrice = BigInt.tryParse(
      transaction['gas_unit_price']?.toString() ?? '',
    );
    final fee = gasUsed != null && gasPrice != null ? gasUsed * gasPrice : null;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, hash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: hash,
      fromAddress: fromAddress,
      toAddress: toAddress,
      amount: WalletTransferService.rawUnitsToAmount(
        rawAmount.abs(),
        asset.decimals,
      ),
      decimals: asset.decimals,
      direction: direction,
      status: activity['is_transaction_success'] == true
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed,
      source: WalletTransactionSource.remote,
      contractAddress: asset.contractAddress,
      feeSymbol: direction == WalletTransactionDirection.outgoing
          ? 'APT'
          : null,
      feeAmount:
          direction == WalletTransactionDirection.outgoing &&
              fee != null &&
              fee > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(fee, 8)
          : null,
      blockNumber: _intFromObject(activity['block_height']),
      timestamp: _aptosTimestamp(activity['transaction_timestamp']),
    );
  }

  String _counterpartyFor({
    required Map<String, dynamic> activity,
    required List<Map<String, dynamic>> activities,
    required String walletAddress,
    required WalletTransactionDirection direction,
  }) {
    final version = activity['transaction_version']?.toString() ?? '';
    final oppositeType = direction == WalletTransactionDirection.incoming
        ? 'withdraw'
        : 'deposit';
    for (final candidate in activities) {
      if (candidate['transaction_version']?.toString() != version) continue;
      final owner = candidate['owner_address']?.toString() ?? '';
      if (owner.isEmpty || owner.toLowerCase() == walletAddress.toLowerCase()) {
        continue;
      }
      final type = candidate['type']?.toString().toLowerCase() ?? '';
      if (type.contains(oppositeType)) return owner;
    }
    return '';
  }

  String _recipientFromPayload(Object? rawPayload) {
    if (rawPayload is! Map) return '';
    final arguments = rawPayload['arguments'];
    if (arguments is! List || arguments.isEmpty) return '';
    final function = rawPayload['function']?.toString() ?? '';
    final recipientIndex = function.contains('primary_fungible_store::transfer')
        ? 1
        : 0;
    if (recipientIndex >= arguments.length) return '';
    return arguments[recipientIndex]?.toString() ?? '';
  }

  String _assetType(ChainBalance asset) {
    if (asset.isNative) return '0x1::aptos_coin::AptosCoin';
    return WalletTransferService.normalizeAptosAddress(
      asset.contractAddress ?? '',
    );
  }

  DateTime? _aptosTimestamp(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final hasTimezone =
        text.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    return DateTime.tryParse(hasTimezone ? text : '${text}Z');
  }
}
