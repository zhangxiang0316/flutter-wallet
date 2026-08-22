/// 首页总资产文本的展示拆分结果。
///
/// 把控制器给出的 `$1234.56` 拆成整数部分 `$1,234` 与小数部分 `.56`，
/// Hero 卡片用两种字号排版金额，整数部分补千分位后大额资产更易读。
class BalanceAmountParts {
  const BalanceAmountParts({required this.whole, this.fraction});

  /// 带货币符号和千分位的整数部分，例如 `$1,234`。
  final String whole;

  /// 含小数点的小数部分，例如 `.56`；原文本没有小数时为 null。
  final String? fraction;
}

/// 拆分总资产文本 [text]。
///
/// 只做展示层格式化，不解析数值，因此 `--` 等占位文本会原样返回。
BalanceAmountParts splitBalanceAmount(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const BalanceAmountParts(whole: '--');
  }
  final decimalMatch = RegExp(r'^(.*)(\.\d+)$').firstMatch(trimmed);
  return BalanceAmountParts(
    whole: _groupThousands(decimalMatch?.group(1) ?? trimmed),
    fraction: decimalMatch?.group(2),
  );
}

/// 给 [source] 末尾的数字串补千分位分隔符，保留货币符号等前缀。
String _groupThousands(String source) {
  final match = RegExp(r'^(\D*)(\d+)$').firstMatch(source);
  if (match == null) {
    return source;
  }
  final digits = match.group(2)!;
  final buffer = StringBuffer(match.group(1)!);
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
