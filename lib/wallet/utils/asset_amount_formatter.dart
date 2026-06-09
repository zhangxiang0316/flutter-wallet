String formatAssetAmount(String amount, {int maxFractionDigits = 8}) {
  final value = amount.trim();
  if (value.isEmpty || maxFractionDigits < 0) {
    return value;
  }

  final dotIndex = value.indexOf('.');
  if (dotIndex < 0) {
    return value;
  }

  final integerPart = value.substring(0, dotIndex);
  final fractionPart = value.substring(dotIndex + 1);
  final clippedFraction = fractionPart.length > maxFractionDigits
      ? fractionPart.substring(0, maxFractionDigits)
      : fractionPart;
  final trimmedFraction = clippedFraction.replaceFirst(RegExp(r'0+$'), '');
  if (trimmedFraction.isEmpty) {
    return integerPart.isEmpty ? '0' : integerPart;
  }
  return '${integerPart.isEmpty ? '0' : integerPart}.$trimmedFraction';
}
