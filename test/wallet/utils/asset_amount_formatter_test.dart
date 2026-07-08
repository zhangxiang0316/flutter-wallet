import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/utils/asset_amount_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatAssetAmount', () {
    test('limits token amounts to 8 decimal places for display', () {
      expect(formatAssetAmount('1'), '1');
      expect(formatAssetAmount('1.2'), '1.2');
      expect(formatAssetAmount('1.2300000000'), '1.23');
      expect(formatAssetAmount('0.123456789'), '0.12345678');
      expect(formatAssetAmount('123.000000001'), '123');
    });
  });
}
