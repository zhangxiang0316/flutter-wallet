import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/sensitive_data_lifecycle.dart';
import 'package:omnicast/widget/sensitive_data_scope.dart';

void main() {
  setUp(() {
    SensitiveDataLifecycle.reset();
  });

  tearDown(() {
    SensitiveDataLifecycle.reset();
  });

  testWidgets('registers while mounted and unregisters when disposed', (
    tester,
  ) async {
    var clearCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SensitiveDataScope(
          protectScreen: false,
          showProtectionToast: false,
          onClear: () => clearCount++,
          child: const Text('sensitive'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    SensitiveDataLifecycle.clearAll();
    expect(clearCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    SensitiveDataLifecycle.clearAll();

    expect(clearCount, 1);
  });
}
