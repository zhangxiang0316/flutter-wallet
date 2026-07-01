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
        developer.log(
          'Solana Helius history failed: $error',
          name: 'WalletTransactionHistoryService',
        );
        if (error is TransactionHistoryLoadException &&
            error.kind == TransactionHistoryFailureKind.rateLimited) {
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
        throw TransactionHistoryLoadException(
          TransactionHistoryFailureKind.provider,
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
      throw TransactionHistoryLoadException(
        TransactionHistoryFailureKind.provider,
        'Solana token history provider failed',
        heliusError ?? error,
      );
    }
  }

  Future<TransactionHistoryPageResult> _loadSolanaHeliusRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final records = <WalletTransactionRecord>[];
    String? before = cursor?.solanaBefore;
    String? nextBefore;
    var hasMore = false;

    for (var page = 0; page < _heliusMaxScanPages; page++) {
      final transactions = await _solanaHeliusTransactions(
        address: asset.address,
        before: before,
      );
      if (transactions.isEmpty) {
        return TransactionHistoryPageResult(records: records, nextCursor: null);
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
        if (records.length >= _historyLimit) break;
      }

      nextBefore ??= _solanaHeliusSignature(transactions.last);
      hasMore = transactions.length >= _heliusPageLimit;
      if (records.length >= _historyLimit ||
          !hasMore ||
          nextBefore == null ||
          nextBefore.isEmpty) {
        break;
      }
      before = nextBefore;
    }

    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: hasMore && nextBefore != null && nextBefore.isNotEmpty
          ? TransactionHistoryCursor.solanaBefore(nextBefore)
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
          'limit': _heliusPageLimit,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final data = response.data;
      if (data is List) return data;
      throw TransactionHistoryLoadException(
        TransactionHistoryFailureKind.provider,
        'Invalid Solana history API response',
        data,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 429) {
        throw const TransactionHistoryLoadException(
          TransactionHistoryFailureKind.rateLimited,
          'Solana history API rate limited',
        );
      }
      throw TransactionHistoryLoadException(
        TransactionHistoryFailureKind.provider,
        'Solana history API request failed',
        error,
      );
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

  String? _solanaHeliusTokenAmount(
    Map<dynamic, dynamic> transfer,
    int decimals,
  ) {
    final raw = transfer['rawTokenAmount'];
    if (raw is Map) {
      final rawAmount = BigInt.tryParse(raw['tokenAmount']?.toString() ?? '');
      final rawDecimals =
          int.tryParse(raw['decimals']?.toString() ?? '') ?? decimals;
      if (rawAmount != null) {
        return WalletTransferService.rawUnitsToAmount(rawAmount, rawDecimals);
      }
    }
    final value = transfer['tokenAmount'];
    if (value == null) return null;
    return _normalizeDecimalString(value.toString());
  }

  bool _solanaHeliusTokenChangeTouchesWallet(
    Map<dynamic, dynamic> change,
    String walletAddress,
  ) {
    final normalizedWallet = walletAddress.trim();
    return change['userAccount']?.toString() == normalizedWallet ||
        change['owner']?.toString() == normalizedWallet ||
        change['account']?.toString() == normalizedWallet ||
        change['tokenAccount']?.toString() == normalizedWallet;
  }

  BigInt? _solanaHeliusSignedTokenRawAmount(
    Map<dynamic, dynamic> change,
    int decimals,
  ) {
    final raw = change['rawTokenAmount'];
    if (raw is Map) {
      return BigInt.tryParse(raw['tokenAmount']?.toString() ?? '');
    }
    final nativeRaw = change['rawAmount'] ?? change['amount'];
    final rawAmount = BigInt.tryParse(nativeRaw?.toString() ?? '');
    if (rawAmount != null) return rawAmount;

    final uiAmount = Decimal.tryParse(
      change['tokenAmount']?.toString() ?? change['uiAmount']?.toString() ?? '',
    );
    if (uiAmount == null) return null;
    final multiplier = Decimal.fromBigInt(BigInt.from(10).pow(decimals));
    return BigInt.tryParse((uiAmount * multiplier).toStringAsFixed(0));
  }

  int _solanaHeliusTokenChangeDecimals(
    Map<dynamic, dynamic> change,
    int fallback,
  ) {
    final raw = change['rawTokenAmount'];
    if (raw is Map) {
      return int.tryParse(raw['decimals']?.toString() ?? '') ?? fallback;
    }
    return int.tryParse(change['decimals']?.toString() ?? '') ?? fallback;
  }

  String? _solanaHeliusFeeAmount(Map<dynamic, dynamic> transaction) {
    final fee = BigInt.tryParse(transaction['fee']?.toString() ?? '');
    if (fee == null || fee == BigInt.zero) return null;
    return WalletTransferService.rawUnitsToAmount(fee, 9);
  }

  String? _solanaHeliusSignature(Object? value) {
    if (value is! Map) return null;
    return value['signature']?.toString();
  }

  Future<TransactionHistoryPageResult> _loadSolanaTokenRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final records = await _loadSolanaTokenRecords(
      walletId: walletId,
      asset: asset,
      before: cursor?.solanaBefore,
    );
    return TransactionHistoryPageResult(
      records: records,
      nextCursor: records.length >= _historyLimit
          ? TransactionHistoryCursor.solanaBefore(records.last.txHash)
          : null,
    );
  }

  Future<TransactionHistoryPageResult> _loadSolanaNativeRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final signatures = await _solanaSignaturesForAddress(
      chain: asset.chainRef,
      address: asset.address,
      before: cursor?.solanaBefore,
    );
    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(_historyLimit)) {
      final transaction = await _solanaParsedTransaction(
        chain: asset.chainRef,
        signature: signature,
      );
      records.addAll(
        _solanaNativeRecordsFromTransaction(
          walletId: walletId,
          asset: asset,
          signature: signature,
          transaction: transaction,
        ),
      );
      if (records.length >= _historyLimit) break;
    }
    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records.take(_historyLimit).toList(growable: false),
      nextCursor: signatures.length >= _historyLimit
          ? TransactionHistoryCursor.solanaBefore(signatures.last)
          : null,
    );
  }

  Future<List<WalletTransactionRecord>> _loadSolanaTokenRecords({
    required String walletId,
    required ChainBalance asset,
    String? before,
  }) async {
    final tokenAccounts = await _solanaTokenAccountsForMint(
      chain: asset.chainRef,
      ownerAddress: asset.address,
      mintAddress: asset.contractAddress ?? '',
    );
    if (tokenAccounts.isEmpty) {
      return const [];
    }

    final signatures = <String>{};
    for (final account in tokenAccounts.take(4)) {
      final accountSignatures = await _solanaSignaturesForAddress(
        chain: asset.chainRef,
        address: account,
        limit: math.max(8, _historyLimit ~/ tokenAccounts.length),
        before: before,
      );
      signatures.addAll(accountSignatures);
      if (signatures.length >= _historyLimit) break;
    }

    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(_historyLimit)) {
      final transaction = await _solanaParsedTransaction(
        chain: asset.chainRef,
        signature: signature,
      );
      records.addAll(
        _solanaTokenRecordsFromTransaction(
          walletId: walletId,
          asset: asset,
          signature: signature,
          transaction: transaction,
          ownedTokenAccounts: tokenAccounts.toSet(),
        ),
      );
      if (records.length >= _historyLimit) break;
    }
    records.sort(_compareRecordTimeDesc);
    return records.take(_historyLimit).toList(growable: false);
  }

  List<WalletTransactionRecord> _solanaNativeRecordsFromTransaction({
    required String walletId,
    required ChainBalance asset,
    required String signature,
    required Map<dynamic, dynamic> transaction,
  }) {
    final records = <WalletTransactionRecord>[];
    final instructions = _solanaInstructions(transaction);
    for (var index = 0; index < instructions.length; index++) {
      final instruction = instructions[index];
      final parsed = instruction is Map ? instruction['parsed'] : null;
      final info = parsed is Map ? parsed['info'] : null;
      if (info is! Map || parsed['type']?.toString() != 'transfer') continue;
      if (instruction['program']?.toString() != 'system') continue;

      final from = info['source']?.toString() ?? '';
      final to = info['destination']?.toString() ?? '';
      if (from != asset.address && to != asset.address) continue;

      final lamports =
          BigInt.tryParse(info['lamports']?.toString() ?? '') ?? BigInt.zero;
      records.add(
        WalletTransactionRecord(
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
          amount: WalletTransferService.rawUnitsToAmount(lamports, 9),
          decimals: 9,
          direction: _directionForAddress(
            walletAddress: asset.address,
            fromAddress: from,
            toAddress: to,
            normalize: (value) => value.trim(),
          ),
          status: _solanaStatus(transaction),
          source: WalletTransactionSource.remote,
          feeAmount: _solanaFeeAmount(transaction),
          feeSymbol: asset.chainRef.symbol,
          timestamp: _dateTimeFromSeconds(transaction['blockTime']),
        ),
      );
    }
    return records;
  }

  List<WalletTransactionRecord> _solanaTokenRecordsFromTransaction({
    required String walletId,
    required ChainBalance asset,
    required String signature,
    required Map<dynamic, dynamic> transaction,
    required Set<String> ownedTokenAccounts,
  }) {
    final records = <WalletTransactionRecord>[];
    final instructions = _solanaInstructions(transaction);
    for (var index = 0; index < instructions.length; index++) {
      final instruction = instructions[index];
      if (instruction is! Map ||
          instruction['program']?.toString() != 'spl-token') {
        continue;
      }
      final parsed = instruction['parsed'];
      final type = parsed is Map ? parsed['type']?.toString() : null;
      if (type != 'transfer' && type != 'transferChecked') continue;
      final info = parsed is Map ? parsed['info'] : null;
      if (info is! Map) continue;

      final mint = info['mint']?.toString();
      if (mint != null && mint.isNotEmpty && mint != asset.contractAddress) {
        continue;
      }
      final source = info['source']?.toString() ?? '';
      final destination = info['destination']?.toString() ?? '';
      final touchesWallet =
          ownedTokenAccounts.contains(source) ||
          ownedTokenAccounts.contains(destination);
      if (!touchesWallet) continue;

      final tokenAmount = info['tokenAmount'];
      final decimals = tokenAmount is Map
          ? int.tryParse(tokenAmount['decimals']?.toString() ?? '') ??
                asset.decimals
          : asset.decimals;
      final rawValue = tokenAmount is Map
          ? BigInt.tryParse(tokenAmount['amount']?.toString() ?? '')
          : BigInt.tryParse(info['amount']?.toString() ?? '');
      if (rawValue == null) continue;

      final direction = ownedTokenAccounts.contains(source)
          ? ownedTokenAccounts.contains(destination)
                ? WalletTransactionDirection.selfTransfer
                : WalletTransactionDirection.outgoing
          : WalletTransactionDirection.incoming;
      records.add(
        WalletTransactionRecord(
          id: _recordId(walletId, asset, '$signature:$index'),
          walletId: walletId,
          chainId: asset.chainId,
          chainName: asset.chainRef.name,
          symbol: asset.symbol,
          assetName: asset.name,
          walletAddress: asset.address,
          txHash: signature,
          fromAddress: info['authority']?.toString() ?? source,
          toAddress: destination,
          amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
          decimals: decimals,
          direction: direction,
          status: _solanaStatus(transaction),
          source: WalletTransactionSource.remote,
          contractAddress: asset.contractAddress,
          feeAmount: _solanaFeeAmount(transaction),
          feeSymbol: asset.chainRef.symbol,
          timestamp: _dateTimeFromSeconds(transaction['blockTime']),
        ),
      );
    }
    return records;
  }

  Future<List<String>> _solanaSignaturesForAddress({
    required WalletChainRef chain,
    required String address,
    int limit = _historyLimit,
    String? before,
  }) async {
    final result = await _solanaRpc(chain, 'getSignaturesForAddress', [
      address,
      {
        'limit': limit,
        if (before != null && before.isNotEmpty) 'before': before,
      },
    ]);
    if (result is! List) {
      return const [];
    }
    return result
        .whereType<Map>()
        .map((item) => item['signature']?.toString() ?? '')
        .where((signature) => signature.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<dynamic, dynamic>> _solanaParsedTransaction({
    required WalletChainRef chain,
    required String signature,
  }) async {
    final result = await _solanaRpc(chain, 'getParsedTransaction', [
      signature,
      {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
    ]);
    if (result is Map) {
      return result;
    }
    return const {};
  }

  Future<List<String>> _solanaTokenAccountsForMint({
    required WalletChainRef chain,
    required String ownerAddress,
    required String mintAddress,
  }) async {
    if (mintAddress.isEmpty) return const [];
    final result = await _solanaRpc(chain, 'getTokenAccountsByOwner', [
      ownerAddress,
      {'mint': mintAddress},
      {'encoding': 'jsonParsed'},
    ]);
    final values = result is Map ? result['value'] : null;
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((item) => item['pubkey']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<dynamic> _solanaInstructions(Map<dynamic, dynamic> transaction) {
    final instructions = <dynamic>[];
    final tx = transaction['transaction'];
    final message = tx is Map ? tx['message'] : null;
    final rootInstructions = message is Map ? message['instructions'] : null;
    if (rootInstructions is List) {
      instructions.addAll(rootInstructions);
    }

    final meta = transaction['meta'];
    final inner = meta is Map ? meta['innerInstructions'] : null;
    if (inner is List) {
      for (final item in inner.whereType<Map>()) {
        final values = item['instructions'];
        if (values is List) {
          instructions.addAll(values);
        }
      }
    }
    return instructions;
  }

  Future<dynamic> _solanaRpc(
    WalletChainRef chain,
    String method,
    List<dynamic> params,
  ) async {
    Object? lastError;
    for (final rpcUrl in _solanaRpcUrls(chain)) {
      try {
        final response = await dio.post(
          rpcUrl,
          data: {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final data = response.data;
        if (data is Map && data.containsKey('result')) {
          return data['result'];
        }
        throw StateError(data is Map ? data.toString() : 'Invalid RPC data');
      } catch (error) {
        if (error is DioException && error.response?.statusCode == 429) {
          throw const TransactionHistoryLoadException(
            TransactionHistoryFailureKind.rateLimited,
            'Solana RPC rate limited',
          );
        }
        lastError = error;
      }
    }
    throw StateError('Solana RPC failed: ${lastError ?? 'unknown'}');
  }

  WalletTransactionStatus _solanaStatus(Map<dynamic, dynamic> transaction) {
    final meta = transaction['meta'];
    if (meta is Map && meta.containsKey('err')) {
      return meta['err'] == null
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed;
    }
    return WalletTransactionStatus.unknown;
  }

  List<String> _solanaRpcUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig) {
      return _mergeUrls(chain.rpcUrls, _solanaRpcFallbacks);
    }
    return _mergeUrls([chain.rpcUrl], _solanaRpcFallbacks);
  }

  String? _solanaFeeAmount(Map<dynamic, dynamic> transaction) {
    final meta = transaction['meta'];
    final fee = meta is Map
        ? BigInt.tryParse(meta['fee']?.toString() ?? '')
        : null;
    if (fee == null || fee == BigInt.zero) return null;
    return WalletTransferService.rawUnitsToAmount(fee, 9);
  }
}
