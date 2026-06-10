/// 格式化资产数量展示文本。
///
/// 链上余额通常带有很多小数位，直接展示会影响列表可读性。该函数只做“展示裁剪”：
/// - 最多保留 [maxFractionDigits] 位小数；
/// - 去掉小数末尾多余的 0；
/// - 整数部分为空时补成 `0`；
/// - 输入为空或 [maxFractionDigits] 为负数时原样返回。
///
/// 注意：这里不会四舍五入，也不会参与转账金额计算，避免展示格式影响真实链上数量。
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
