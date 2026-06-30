part of '../wallet_transaction_history_service.dart';

mixin _TransactionHistoryProviderHelpers {
  Dio get dio;

  WalletHistoryApiConfig get apiConfig;

  WalletTransactionDirection _directionForAddress({
    required String walletAddress,
    required String fromAddress,
    required String toAddress,
    required String Function(String value) normalize,
  }) {
    final wallet = normalize(walletAddress);
    final from = normalize(fromAddress);
    final to = normalize(toAddress);
    if (wallet.isEmpty) return WalletTransactionDirection.unknown;
    if (from == wallet && to == wallet) {
      return WalletTransactionDirection.selfTransfer;
    }
    if (to == wallet) return WalletTransactionDirection.incoming;
    if (from == wallet) return WalletTransactionDirection.outgoing;
    return WalletTransactionDirection.unknown;
  }

  List<String> _mergeUrls(List<String> primary, List<String> fallback) {
    final values = <String>{};
    for (final url in [...primary, ...fallback]) {
      final normalized = url.trim();
      if (normalized.isNotEmpty) {
        values.add(normalized);
      }
    }
    return values.toList(growable: false);
  }

  String _recordId(String walletId, ChainBalance asset, String txHash) {
    return [
      'remote',
      walletId,
      asset.chainId,
      _assetKey(asset),
      txHash.toLowerCase(),
    ].join(':');
  }

  String _assetKey(ChainBalance asset) {
    final contract = asset.contractAddress?.trim() ?? '';
    return [
      asset.chainId,
      contract.isEmpty ? 'native' : contract.toLowerCase(),
      asset.symbol.toUpperCase(),
    ].join(':');
  }

  int _compareRecordTimeDesc(
    WalletTransactionRecord left,
    WalletTransactionRecord right,
  ) {
    final leftTime = left.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }

  String _normalizeEvmDisplayAddress(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return '0x${trimmed.substring(2).toLowerCase()}';
  }

  String _normalizeEvmCompareAddress(String value) {
    return value.trim().toLowerCase();
  }

  String _evmAddressTopic(String address) {
    final normalized = _normalizeEvmCompareAddress(
      address,
    ).replaceFirst('0x', '');
    return '0x${normalized.padLeft(64, '0')}';
  }

  String _evmAddressFromTopic(String topic) {
    final value = topic.replaceFirst('0x', '');
    if (value.length < 40) return topic;
    return '0x${value.substring(value.length - 40).toLowerCase()}';
  }

  String _normalizeTronDisplayAddress(String value) {
    final trimmed = value.trim();
    if (RegExp(r'^(41)?[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      final hexValue = trimmed.startsWith('41') ? trimmed : '41$trimmed';
      return _tronHexToAddress(hexValue);
    }
    return trimmed;
  }

  String _normalizeTronCompareAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'^(41)?[0-9a-fA-F]{40}$').hasMatch(trimmed)) {
      final hexValue = trimmed.startsWith('41') ? trimmed : '41$trimmed';
      return hexValue.toLowerCase();
    }
    try {
      return WalletTransferService.tronAddressToHex(trimmed).toLowerCase();
    } catch (_) {
      return trimmed;
    }
  }

  Map<dynamic, dynamic> _firstTronContractValue(Map<dynamic, dynamic> item) {
    final rawData = item['raw_data'];
    final contracts = rawData is Map ? rawData['contract'] : null;
    if (contracts is! List || contracts.isEmpty || contracts.first is! Map) {
      return const {};
    }
    final parameter = (contracts.first as Map)['parameter'];
    final value = parameter is Map ? parameter['value'] : null;
    return value is Map ? value : const {};
  }

  String? _nestedValue(Map<dynamic, dynamic> item, List<String> keys) {
    dynamic current = item;
    for (final key in keys) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current?.toString();
  }

  DateTime? _dateTimeFromSeconds(Object? value) {
    final seconds = int.tryParse(value?.toString() ?? '');
    if (seconds == null || seconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  DateTime? _dateTimeFromMilliseconds(Object? value) {
    final milliseconds = int.tryParse(value?.toString() ?? '');
    if (milliseconds == null || milliseconds <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  DateTime? _dateTimeFromIso(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  int? _intFromObject(Object? value) {
    return int.tryParse(value?.toString() ?? '');
  }

  BigInt _parseHexQuantity(String value) {
    final normalized = value.trim().replaceFirst('0x', '');
    if (normalized.isEmpty) return BigInt.zero;
    return BigInt.parse(normalized, radix: 16);
  }

  String _hexQuantity(BigInt value) {
    return '0x${value.toRadixString(16)}';
  }

  String _tronHexToAddress(String value) {
    final bytes = Uint8List.fromList(hex.decode(value));
    final firstHash = _sha256(bytes);
    final secondHash = _sha256(firstHash);
    final checksum = secondHash.take(4);
    return _base58Encode(Uint8List.fromList([...bytes, ...checksum]));
  }

  Uint8List _sha256(Uint8List input) {
    return SHA256Digest().process(input);
  }

  String _base58Encode(Uint8List bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = value * BigInt.from(256) + BigInt.from(byte);
    }

    final base = BigInt.from(58);
    final output = StringBuffer();
    while (value > BigInt.zero) {
      final mod = value % base;
      output.write(CryptoConstants.base58Alphabet[mod.toInt()]);
      value ~/= base;
    }

    for (final byte in bytes) {
      if (byte == 0) {
        output.write(CryptoConstants.base58Alphabet[0]);
      } else {
        break;
      }
    }
    return output.toString().split('').reversed.join();
  }

  String _normalizeDecimalString(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '0';
    if (!normalized.contains('.')) return normalized;
    return normalized
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
