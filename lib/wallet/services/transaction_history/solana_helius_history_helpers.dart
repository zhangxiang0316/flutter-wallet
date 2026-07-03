part of '../wallet_transaction_history_service.dart';

String? _solanaHeliusTokenAmount(Map<dynamic, dynamic> transfer, int decimals) {
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
  return _normalizeSolanaHeliusDecimalString(value.toString());
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

String _normalizeSolanaHeliusDecimalString(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return '0';
  if (!normalized.contains('.')) return normalized;
  return normalized
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
