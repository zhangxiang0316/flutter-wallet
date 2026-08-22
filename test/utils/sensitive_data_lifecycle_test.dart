import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/sensitive_data_lifecycle.dart';

void main() {
  setUp(SensitiveDataLifecycle.reset);
  tearDown(SensitiveDataLifecycle.reset);

  test('clears every registered sensitive data holder', () {
    var firstClearCount = 0;
    var secondClearCount = 0;
    void clearFirst() => firstClearCount++;
    void clearSecond() => secondClearCount++;
    SensitiveDataLifecycle.register(clearFirst);
    SensitiveDataLifecycle.register(clearSecond);

    SensitiveDataLifecycle.clearAll();

    expect(firstClearCount, 1);
    expect(secondClearCount, 1);
  });

  test('does not retain an unregistered data holder', () {
    var clearCount = 0;
    void clear() => clearCount++;
    SensitiveDataLifecycle.register(clear);
    SensitiveDataLifecycle.unregister(clear);

    SensitiveDataLifecycle.clearAll();

    expect(clearCount, 0);
  });

  test('allows a callback to unregister itself while clearing', () {
    var clearCount = 0;
    late void Function() clear;
    clear = () {
      clearCount++;
      SensitiveDataLifecycle.unregister(clear);
    };
    SensitiveDataLifecycle.register(clear);

    SensitiveDataLifecycle.clearAll();
    SensitiveDataLifecycle.clearAll();

    expect(clearCount, 1);
  });
}
