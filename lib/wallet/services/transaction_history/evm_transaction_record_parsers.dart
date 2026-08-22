part of '../wallet_transaction_history_service.dart';

extension _EvmTransactionRecordParsers on _EvmTransactionHistoryProvider {
  Map<String, dynamic>? _decodeBlockscoutCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    try {
      final decoded = jsonDecode(cursor);
      if (decoded is! Map) return null;
      return {
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      };
    } catch (_) {
      return null;
    }
  }

  WalletTransactionRecord? _evmNativeRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeEvmDisplayAddress(item['to']?.toString() ?? '');
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final gasUsed =
        BigInt.tryParse(item['gasUsed']?.toString() ?? '') ?? BigInt.zero;
    final gasPrice =
        BigInt.tryParse(item['gasPrice']?.toString() ?? '') ?? BigInt.zero;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, asset.decimals),
      decimals: asset.decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _evmExplorerStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(item['timeStamp']),
    );
  }

  WalletTransactionRecord? _evmTokenRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
    String? transferIndex,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;
    final contractAddress = item['contractAddress']?.toString() ?? '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final decimals =
        int.tryParse(item['tokenDecimal']?.toString() ?? '') ?? asset.decimals;
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final from = _normalizeEvmDisplayAddress(item['from']?.toString() ?? '');
    final to = _normalizeEvmDisplayAddress(item['to']?.toString() ?? '');
    final gasUsed =
        BigInt.tryParse(item['gasUsed']?.toString() ?? '') ?? BigInt.zero;
    final gasPrice =
        BigInt.tryParse(item['gasPrice']?.toString() ?? '') ?? BigInt.zero;
    final eventIndex = _normalizedEventIndex(item['logIndex']) ?? transferIndex;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:${eventIndex ?? ''}'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
      decimals: decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _evmExplorerStatus(item),
      source: WalletTransactionSource.remote,
      eventIndex: eventIndex,
      contractAddress: asset.contractAddress,
      feeAmount: gasUsed > BigInt.zero && gasPrice > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: int.tryParse(item['blockNumber']?.toString() ?? ''),
      timestamp: _dateTimeFromSeconds(item['timeStamp']),
    );
  }

  WalletTransactionRecord? _evmNativeRecordFromBlockscout({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final from = _normalizeEvmDisplayAddress(_blockscoutAddress(item['from']));
    final to = _normalizeEvmDisplayAddress(_blockscoutAddress(item['to']));
    final rawValue =
        BigInt.tryParse(item['value']?.toString() ?? '') ?? BigInt.zero;
    final feeValue = _blockscoutFeeValue(item);

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, txHash),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, asset.decimals),
      decimals: asset.decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: _blockscoutStatus(item),
      source: WalletTransactionSource.remote,
      feeAmount: feeValue > BigInt.zero
          ? WalletTransferService.rawUnitsToAmount(feeValue, 18)
          : null,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['timestamp']),
    );
  }

  WalletTransactionRecord? _evmTokenRecordFromBlockscout({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
    String? transferIndex,
  }) {
    final txHash = item['transaction_hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;

    final token = item['token'];
    final contractAddress = token is Map
        ? token['address_hash']?.toString() ?? ''
        : '';
    if (!_sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
      return null;
    }

    final total = item['total'];
    final decimals = total is Map
        ? int.tryParse(total['decimals']?.toString() ?? '') ?? asset.decimals
        : token is Map
        ? int.tryParse(token['decimals']?.toString() ?? '') ?? asset.decimals
        : asset.decimals;
    final rawValue = total is Map
        ? BigInt.tryParse(total['value']?.toString() ?? '')
        : null;
    if (rawValue == null) return null;

    final from = _normalizeEvmDisplayAddress(_blockscoutAddress(item['from']));
    final to = _normalizeEvmDisplayAddress(_blockscoutAddress(item['to']));
    final eventIndex =
        _normalizedEventIndex(item['log_index']) ?? transferIndex;

    return WalletTransactionRecord(
      id: _recordId(walletId, asset, '$txHash:${eventIndex ?? ''}'),
      walletId: walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: from,
      toAddress: to,
      amount: WalletTransferService.rawUnitsToAmount(rawValue, decimals),
      decimals: decimals,
      direction: _directionForAddress(
        walletAddress: asset.address,
        fromAddress: from,
        toAddress: to,
        normalize: _normalizeEvmCompareAddress,
      ),
      status: WalletTransactionStatus.success,
      source: WalletTransactionSource.remote,
      eventIndex: eventIndex,
      contractAddress: asset.contractAddress,
      feeSymbol: asset.chainRef.symbol,
      blockNumber: _intFromObject(item['block_number']),
      timestamp: _dateTimeFromIso(item['timestamp']),
    );
  }

  WalletTransactionStatus _evmExplorerStatus(Map<dynamic, dynamic> item) {
    if (item['isError']?.toString() == '1' ||
        item['txreceipt_status']?.toString() == '0') {
      return WalletTransactionStatus.failed;
    }
    if (item['txreceipt_status']?.toString() == '1' ||
        item['isError']?.toString() == '0' ||
        !item.containsKey('txreceipt_status')) {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  WalletTransactionStatus _blockscoutStatus(Map<dynamic, dynamic> item) {
    final status = item['status']?.toString().toLowerCase() ?? '';
    final result = item['result']?.toString().toLowerCase() ?? '';
    if (status == 'error' ||
        result.contains('error') ||
        result.contains('fail') ||
        result.contains('out of gas')) {
      return WalletTransactionStatus.failed;
    }
    if (status == 'ok' || result == 'success') {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  String _blockscoutAddress(Object? value) {
    if (value is Map) {
      return value['hash']?.toString() ?? '';
    }
    return value?.toString() ?? '';
  }

  BigInt _blockscoutFeeValue(Map<dynamic, dynamic> item) {
    final fee = item['fee'];
    if (fee is Map) {
      return BigInt.tryParse(fee['value']?.toString() ?? '') ?? BigInt.zero;
    }
    return BigInt.tryParse(fee?.toString() ?? '') ?? BigInt.zero;
  }

  bool _sameEvmAddress(String left, String right) {
    final normalizedLeft = _normalizeEvmCompareAddress(left);
    final normalizedRight = _normalizeEvmCompareAddress(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }
}
