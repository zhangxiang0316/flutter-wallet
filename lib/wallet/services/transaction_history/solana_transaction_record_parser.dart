part of '../wallet_transaction_history_service.dart';

/// Converts parsed Solana RPC transactions into wallet transaction records.
class _SolanaTransactionRecordParser with _TransactionHistoryProviderHelpers {
  _SolanaTransactionRecordParser({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  List<WalletTransactionRecord> nativeRecords({
    required String walletId,
    required ChainBalance asset,
    required String signature,
    required Map<dynamic, dynamic> transaction,
  }) {
    final records = <WalletTransactionRecord>[];
    final instructions = _instructions(transaction);
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
          status: _status(transaction),
          source: WalletTransactionSource.remote,
          feeAmount: _feeAmount(transaction),
          feeSymbol: asset.chainRef.symbol,
          timestamp: _dateTimeFromSeconds(transaction['blockTime']),
        ),
      );
    }
    return records;
  }

  List<WalletTransactionRecord> tokenRecords({
    required String walletId,
    required ChainBalance asset,
    required String signature,
    required Map<dynamic, dynamic> transaction,
    required Set<String> ownedTokenAccounts,
  }) {
    final records = <WalletTransactionRecord>[];
    final instructions = _instructions(transaction);
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
      if (!ownedTokenAccounts.contains(source) &&
          !ownedTokenAccounts.contains(destination)) {
        continue;
      }

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
          status: _status(transaction),
          source: WalletTransactionSource.remote,
          contractAddress: asset.contractAddress,
          feeAmount: _feeAmount(transaction),
          feeSymbol: asset.chainRef.symbol,
          timestamp: _dateTimeFromSeconds(transaction['blockTime']),
        ),
      );
    }
    return records;
  }

  List<dynamic> _instructions(Map<dynamic, dynamic> transaction) {
    final instructions = <dynamic>[];
    final tx = transaction['transaction'];
    final message = tx is Map ? tx['message'] : null;
    final rootInstructions = message is Map ? message['instructions'] : null;
    if (rootInstructions is List) instructions.addAll(rootInstructions);

    final meta = transaction['meta'];
    final inner = meta is Map ? meta['innerInstructions'] : null;
    if (inner is List) {
      for (final item in inner.whereType<Map>()) {
        final values = item['instructions'];
        if (values is List) instructions.addAll(values);
      }
    }
    return instructions;
  }

  WalletTransactionStatus _status(Map<dynamic, dynamic> transaction) {
    final meta = transaction['meta'];
    if (meta is Map && meta.containsKey('err')) {
      return meta['err'] == null
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed;
    }
    return WalletTransactionStatus.unknown;
  }

  String? _feeAmount(Map<dynamic, dynamic> transaction) {
    final meta = transaction['meta'];
    final fee = meta is Map
        ? BigInt.tryParse(meta['fee']?.toString() ?? '')
        : null;
    if (fee == null || fee == BigInt.zero) return null;
    return WalletTransferService.rawUnitsToAmount(fee, 9);
  }
}
