import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/screen_security.dart';

void main() {
  tearDown(() {
    expect(ScreenSecurity.activeLeaseCount, 0);
    ScreenSecurity.resetForTesting();
  });

  test(
    'nested leases only enable once and disable after the last release',
    () async {
      final operations = <bool>[];
      ScreenSecurity.setPlatformOperationForTesting((enabled) async {
        operations.add(enabled);
        return enabled
            ? ScreenSecurityState.enabled
            : ScreenSecurityState.disabled;
      });

      final outer = await ScreenSecurity.acquire();
      final inner = await ScreenSecurity.acquire();

      expect(outer.state, ScreenSecurityState.enabled);
      expect(inner.state, ScreenSecurityState.enabled);
      expect(operations, [true]);
      expect(ScreenSecurity.activeLeaseCount, 2);

      await inner.release();
      expect(operations, [true]);
      expect(ScreenSecurity.currentState, ScreenSecurityState.enabled);

      await outer.release();
      expect(operations, [true, false]);
      expect(ScreenSecurity.currentState, ScreenSecurityState.disabled);
    },
  );

  test(
    'returns unsupported without pretending protection is enabled',
    () async {
      ScreenSecurity.setPlatformOperationForTesting(
        (_) async => ScreenSecurityState.unsupported,
      );

      final lease = await ScreenSecurity.acquire();

      expect(lease.state, ScreenSecurityState.unsupported);
      expect(ScreenSecurity.currentState, ScreenSecurityState.unsupported);
      await lease.release();
    },
  );

  test('returns failed when the platform cannot enable protection', () async {
    ScreenSecurity.setPlatformOperationForTesting(
      (_) async => ScreenSecurityState.failed,
    );

    final lease = await ScreenSecurity.acquire();

    expect(lease.state, ScreenSecurityState.failed);
    expect(ScreenSecurity.currentState, ScreenSecurityState.failed);
    await lease.release();
  });

  test('converts an unexpected platform exception into failed', () async {
    ScreenSecurity.setPlatformOperationForTesting((_) async {
      throw StateError('channel failed');
    });

    final lease = await ScreenSecurity.acquire();

    expect(lease.state, ScreenSecurityState.failed);
    await lease.release();
  });
}
