import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/home/view/widgets/wallet_overview/balance_amount_parts.dart';

void main() {
  group('splitBalanceAmount', () {
    test('拆分货币符号、千分位整数和小数部分', () {
      final parts = splitBalanceAmount(r'$1234567.89');
      expect(parts.whole, r'$1,234,567');
      expect(parts.fraction, '.89');
    });

    test('不足千位时不插入分隔符', () {
      final parts = splitBalanceAmount(r'$0.00');
      expect(parts.whole, r'$0');
      expect(parts.fraction, '.00');
    });

    test('恰好三位数不会出现前导分隔符', () {
      final parts = splitBalanceAmount(r'$123.45');
      expect(parts.whole, r'$123');
      expect(parts.fraction, '.45');
    });

    test('没有小数部分时 fraction 为 null', () {
      final parts = splitBalanceAmount(r'$12000');
      expect(parts.whole, r'$12,000');
      expect(parts.fraction, isNull);
    });

    test('占位文本原样返回', () {
      final parts = splitBalanceAmount('--');
      expect(parts.whole, '--');
      expect(parts.fraction, isNull);
    });

    test('空文本回退为占位符', () {
      final parts = splitBalanceAmount('   ');
      expect(parts.whole, '--');
      expect(parts.fraction, isNull);
    });
  });
}
