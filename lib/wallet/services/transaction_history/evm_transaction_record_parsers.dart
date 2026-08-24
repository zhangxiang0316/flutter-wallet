part of '../wallet_transaction_history_service.dart';

class _EvmTransactionRecordParser with _TransactionHistoryProviderHelpers {
  _EvmTransactionRecordParser({required this.dio, required this.apiConfig});

  @override
  final Dio dio;

  @override
  final WalletHistoryApiConfig apiConfig;

  Map<String, dynamic>? decodeBlockscoutCursor(String? cursor) {
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

  WalletTransactionRecord? nativeRecordFromExplorer({
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

  WalletTransactionRecord? tokenRecordFromExplorer({
    required String walletId,
    required ChainBalance asset,
    required Map<dynamic, dynamic> item,
    String? transferIndex,
  }) {
    final txHash = item['hash']?.toString() ?? '';
    if (txHash.isEmpty) return null;
    final contractAddress = item['contractAddress']?.toString() ?? '';
    if (!sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
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

  WalletTransactionRecord? nativeRecordFromBlockscout({
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

  WalletTransactionRecord? tokenRecordFromBlockscout({
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
    if (!sameEvmAddress(contractAddress, asset.contractAddress ?? '')) {
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

  WalletTransactionRecord nativeRecordFromRpc({
    required String walletId,
    required ChainBalance asset,
    required String requestedHash,
    required Map<dynamic, dynamic> transaction,
    required Map<dynamic, dynamic> receipt,
    required DateTime? timestamp,
  }) {
    final txHash =
        transaction['hash']?.toString() ??
        receipt['transactionHash']?.toString() ??
        requestedHash;
    final from = _normalizeEvmDisplayAddress(
      transaction['from']?.toString() ?? receipt['from']?.toString() ?? '',
    );
    final to = _normalizeEvmDisplayAddress(
      transaction['to']?.toString() ?? receipt['to']?.toString() ?? '',
    );
    final rawValue = rpcQuantityToBigInt(transaction['value']);

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
      status: _receiptStatus(receipt),
      source: WalletTransactionSource.remote,
      feeAmount: _receiptFeeAmount(
        receipt,
        fallbackGasPrice: transaction['gasPrice'],
      ),
      feeSymbol: asset.chainRef.symbol,
      blockNumber: hexIntFromObject(
        transaction['blockNumber'] ?? receipt['blockNumber'],
      ),
      timestamp: timestamp,
    );
  }

  WalletTransactionRecord? tokenRecordFromRpcLog({
    required String walletId,
    required ChainBalance asset,
    required String requestedHash,
    required Map<dynamic, dynamic> receipt,
    required Map<dynamic, dynamic> log,
    required DateTime? timestamp,
  }) {
    if (!isMatchingTransferLog(asset, log)) return null;
    final topics = log['topics'];
    if (topics is! List || topics.length < 3) return null;

    final from = _evmAddressFromTopic(topics[1]?.toString() ?? '');
    final to = _evmAddressFromTopic(topics[2]?.toString() ?? '');
    final direction = _directionForAddress(
      walletAddress: asset.address,
      fromAddress: from,
      toAddress: to,
      normalize: _normalizeEvmCompareAddress,
    );
    if (direction == WalletTransactionDirection.unknown) return null;

    final txHash =
        log['transactionHash']?.toString() ??
        receipt['transactionHash']?.toString() ??
        requestedHash;
    final eventIndex = _normalizedEventIndex(log['logIndex']);
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
      amount: WalletTransferService.rawUnitsToAmount(
        rpcQuantityToBigInt(log['data']),
        asset.decimals,
      ),
      decimals: asset.decimals,
      direction: direction,
      status: _receiptStatus(receipt),
      source: WalletTransactionSource.remote,
      eventIndex: eventIndex,
      contractAddress: asset.contractAddress,
      feeAmount: _receiptFeeAmount(receipt),
      feeSymbol: asset.chainRef.symbol,
      blockNumber: hexIntFromObject(
        log['blockNumber'] ?? receipt['blockNumber'],
      ),
      timestamp: timestamp,
    );
  }

  bool isMatchingTransferLog(ChainBalance asset, Map<dynamic, dynamic> log) {
    final logAddress = log['address']?.toString() ?? '';
    if (logAddress.isNotEmpty &&
        !sameEvmAddress(logAddress, asset.contractAddress ?? '')) {
      return false;
    }
    final topics = log['topics'];
    if (topics is! List || topics.length < 3) return false;
    return topics.first.toString().toLowerCase() ==
        CryptoConstants.evmTransferEventTopic.toLowerCase();
  }

  DateTime? dateTimeFromRpcSeconds(Object? value) {
    final seconds = hexIntFromObject(value);
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  int? hexIntFromObject(Object? value) {
    if (value is int) return value;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('0x')) {
      return _parseHexQuantity(text).toInt();
    }
    return int.tryParse(text);
  }

  BigInt rpcQuantityToBigInt(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return BigInt.zero;
    if (text.toLowerCase().startsWith('0x')) return _parseHexQuantity(text);
    return BigInt.tryParse(text) ?? BigInt.zero;
  }

  String? rpcQuantityParam(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('0x')) return text;
    final decimal = BigInt.tryParse(text);
    return decimal == null ? null : _hexQuantity(decimal);
  }

  WalletTransactionStatus _receiptStatus(Map<dynamic, dynamic> receipt) {
    final status = receipt['status']?.toString().toLowerCase() ?? '';
    if (status == '0x0' || status == '0') {
      return WalletTransactionStatus.failed;
    }
    if (status == '0x1' || status == '1') {
      return WalletTransactionStatus.success;
    }
    return WalletTransactionStatus.unknown;
  }

  String? _receiptFeeAmount(
    Map<dynamic, dynamic> receipt, {
    Object? fallbackGasPrice,
  }) {
    final gasUsed = rpcQuantityToBigInt(receipt['gasUsed']);
    final gasPrice = rpcQuantityToBigInt(
      receipt['effectiveGasPrice'] ?? receipt['gasPrice'] ?? fallbackGasPrice,
    );
    if (gasUsed <= BigInt.zero || gasPrice <= BigInt.zero) return null;
    return WalletTransferService.rawUnitsToAmount(gasUsed * gasPrice, 18);
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

  bool sameEvmAddress(String left, String right) {
    final normalizedLeft = _normalizeEvmCompareAddress(left);
    final normalizedRight = _normalizeEvmCompareAddress(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }
}
