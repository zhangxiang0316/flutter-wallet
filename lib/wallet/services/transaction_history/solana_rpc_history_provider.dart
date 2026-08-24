part of '../wallet_transaction_history_service.dart';

extension _SolanaRpcHistoryProvider on _SolanaTransactionHistoryProvider {
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
      nextCursor:
          records.length >= _SolanaTransactionHistoryProvider._historyLimit
          ? TransactionHistoryCursor.solanaBefore(records.last.txHash)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
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
    for (final signature in signatures.take(
      _SolanaTransactionHistoryProvider._historyLimit,
    )) {
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
      if (records.length >= _SolanaTransactionHistoryProvider._historyLimit) {
        break;
      }
    }
    records.sort(_compareRecordTimeDesc);
    return TransactionHistoryPageResult(
      records: records
          .take(_SolanaTransactionHistoryProvider._historyLimit)
          .toList(growable: false),
      nextCursor:
          signatures.length >= _SolanaTransactionHistoryProvider._historyLimit
          ? TransactionHistoryCursor.solanaBefore(signatures.last)
          : null,
      emptyReason: records.isEmpty
          ? TransactionHistoryFailureKind.noRecords
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
        limit: math.max(
          8,
          _SolanaTransactionHistoryProvider._historyLimit ~/
              tokenAccounts.length,
        ),
        before: before,
      );
      signatures.addAll(accountSignatures);
      if (signatures.length >=
          _SolanaTransactionHistoryProvider._historyLimit) {
        break;
      }
    }

    final records = <WalletTransactionRecord>[];
    for (final signature in signatures.take(
      _SolanaTransactionHistoryProvider._historyLimit,
    )) {
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
      if (records.length >= _SolanaTransactionHistoryProvider._historyLimit) {
        break;
      }
    }
    records.sort(_compareRecordTimeDesc);
    return records
        .take(_SolanaTransactionHistoryProvider._historyLimit)
        .toList(growable: false);
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
    int limit = _SolanaTransactionHistoryProvider._historyLimit,
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
    try {
      final data = await RpcRetryHelper.executeJsonRpc(
        dio: dio,
        rpcUrls: _solanaRpcUrls(chain),
        method: method,
        params: params,
        chainName: 'Solana',
        logName: 'WalletTransactionHistoryService',
      );
      if (data.containsKey('result')) {
        return data['result'];
      }
      throw _historyLoadException('Invalid Solana RPC data', data);
    } catch (error) {
      throw _historyLoadException('Solana RPC failed', error);
    }
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
      return _mergeUrls(
        chain.rpcUrls,
        _SolanaTransactionHistoryProvider._solanaRpcFallbacks,
      );
    }
    return _mergeUrls([
      chain.rpcUrl,
    ], _SolanaTransactionHistoryProvider._solanaRpcFallbacks);
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
