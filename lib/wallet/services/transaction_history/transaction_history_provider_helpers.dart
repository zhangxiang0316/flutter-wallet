part of '../wallet_transaction_history_service.dart';

mixin _TransactionHistoryProviderHelpers {
  Dio get dio;

  WalletHistoryApiConfig get apiConfig;

  TransactionHistoryLoadException _historyLoadException(
    String message,
    Object? error, {
    TransactionHistoryFailureKind? fallbackKind,
  }) {
    return TransactionHistoryLoadException(
      _historyFailureKindFromError(error) ??
          fallbackKind ??
          TransactionHistoryFailureKind.providerFailed,
      message,
      error,
    );
  }

  TransactionHistoryFailureKind? _historyFailureKindFromError(Object? error) {
    if (error is TransactionHistoryLoadException) {
      return error.kind;
    }
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return TransactionHistoryFailureKind.timeout;
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 429) {
        return TransactionHistoryFailureKind.rateLimited;
      }
      if (statusCode == 401 || statusCode == 403) {
        return TransactionHistoryFailureKind.apiKeyInvalid;
      }
      final text = _historyErrorText(error);
      if (_looksLikeRateLimit(text)) {
        return TransactionHistoryFailureKind.rateLimited;
      }
      if (_looksLikeApiKeyMissing(text)) {
        return TransactionHistoryFailureKind.apiKeyMissing;
      }
      if (_looksLikeApiKeyInvalid(text)) {
        return TransactionHistoryFailureKind.apiKeyInvalid;
      }
    }

    final text = _historyErrorText(error);
    if (_looksLikeRateLimit(text)) {
      return TransactionHistoryFailureKind.rateLimited;
    }
    if (_looksLikeApiKeyMissing(text)) {
      return TransactionHistoryFailureKind.apiKeyMissing;
    }
    if (_looksLikeApiKeyInvalid(text)) {
      return TransactionHistoryFailureKind.apiKeyInvalid;
    }
    if (_looksLikeTimeout(text)) {
      return TransactionHistoryFailureKind.timeout;
    }
    return null;
  }

  String _historyErrorText(Object? error) {
    if (error == null) return '';
    if (error is DioException) {
      return [
        error.message,
        error.response?.statusMessage,
        error.response?.data,
      ].whereType<Object>().map((value) => value.toString()).join(' ');
    }
    return error.toString();
  }

  bool _looksLikeRateLimit(String value) {
    final text = value.toLowerCase();
    return text.contains('rate limit') ||
        text.contains('too many requests') ||
        text.contains('max rate') ||
        text.contains('429');
  }

  bool _looksLikeApiKeyMissing(String value) {
    final text = value.toLowerCase();
    return text.contains('missing api key') ||
        text.contains('apikey is missing') ||
        text.contains('api key is missing') ||
        text.contains('no api key');
  }

  bool _looksLikeApiKeyInvalid(String value) {
    final text = value.toLowerCase();
    return text.contains('invalid api key') ||
        text.contains('invalid apikey') ||
        text.contains('invalid api-key') ||
        text.contains('api key invalid') ||
        text.contains('unauthorized') ||
        text.contains('forbidden');
  }

  bool _looksLikeTimeout(String value) {
    final text = value.toLowerCase();
    return text.contains('timeout') || text.contains('timed out');
  }

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
    return RpcRetryHelper.mergeRpcUrls(primary, fallback);
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

  /// 将不同 EVM 数据源返回的十六进制/十进制事件序号统一为十进制字符串。
  String? _normalizedEventIndex(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = text.toLowerCase().startsWith('0x')
        ? BigInt.tryParse(text.substring(2), radix: 16)
        : BigInt.tryParse(text);
    return parsed?.toString() ?? text;
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
