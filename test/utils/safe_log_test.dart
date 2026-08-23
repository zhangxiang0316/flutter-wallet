import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/safe_log.dart';

void main() {
  test('redacts credentials, EVM addresses, and private-key shaped values', () {
    const apiKey = 'sk-test-secret';
    const address = '0x1111111111111111111111111111111111111111';
    const privateKey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    final result = SafeLog.sanitize(
      'url?apiKey=$apiKey address=$address privateKey=$privateKey',
    );

    expect(result, isNot(contains(apiKey)));
    expect(result, isNot(contains(address)));
    expect(result, isNot(contains(privateKey)));
    expect(result, contains('[REDACTED]'));
    expect(result, contains('[REDACTED]'));
  });
}
