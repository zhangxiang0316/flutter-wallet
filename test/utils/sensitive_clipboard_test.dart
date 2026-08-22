import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/sensitive_clipboard.dart';

void main() {
  test('clears clipboard when copied sensitive value is unchanged', () async {
    final gateway = _MemoryClipboardGateway();
    final clipboard = SensitiveClipboard(gateway: gateway);

    await clipboard.copy(
      'private-key',
      clearAfter: const Duration(milliseconds: 10),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(gateway.text, isEmpty);
  });

  test(
    'preserves clipboard when user copied a different value later',
    () async {
      final gateway = _MemoryClipboardGateway();
      final clipboard = SensitiveClipboard(gateway: gateway);

      await clipboard.copy(
        'private-key',
        clearAfter: const Duration(milliseconds: 10),
      );
      await gateway.writeText('new-user-value');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(gateway.text, 'new-user-value');
    },
  );

  test('a newer sensitive copy replaces the previous clear task', () async {
    final gateway = _MemoryClipboardGateway();
    final clipboard = SensitiveClipboard(gateway: gateway);

    await clipboard.copy(
      'first-secret',
      clearAfter: const Duration(milliseconds: 10),
    );
    await clipboard.copy(
      'second-secret',
      clearAfter: const Duration(milliseconds: 40),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(gateway.text, 'second-secret');

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(gateway.text, isEmpty);
  });
}

class _MemoryClipboardGateway implements ClipboardGateway {
  String? text;

  @override
  Future<String?> readText() async => text;

  @override
  Future<void> writeText(String text) async {
    this.text = text;
  }
}
