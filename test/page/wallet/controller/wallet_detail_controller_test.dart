import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/wallet/controller/wallet_detail_controller.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/services/wallet_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('automatically hides an unlocked private key and mnemonic', () async {
    final controller = WalletDetailController(
      repository: _FakeWalletRepository(),
      secretRevealDuration: const Duration(milliseconds: 20),
    )..wallet = _wallet;
    addTearDown(controller.onClose);

    expect(await controller.unlockPrivateKey('password'), isTrue);
    expect(await controller.unlockMnemonic('password'), isTrue);
    expect(controller.privateKeyText, _privateKey);
    expect(controller.mnemonicText, _mnemonic);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.privateKeyText, isEmpty);
    expect(controller.mnemonicText, isEmpty);
    expect(controller.privateKeyRemainingSeconds, 0);
    expect(controller.mnemonicRemainingSeconds, 0);
  });

  test('clears revealed secrets as soon as the app becomes inactive', () async {
    final controller = WalletDetailController(
      repository: _FakeWalletRepository(),
    )..wallet = _wallet;
    addTearDown(controller.onClose);
    await controller.unlockPrivateKey('password');
    await controller.unlockMnemonic('password');

    controller.onInactive();

    expect(controller.privateKeyText, isEmpty);
    expect(controller.mnemonicText, isEmpty);
  });

  test(
    'does not reveal a key read that finishes after lifecycle clear',
    () async {
      final repository = _DelayedWalletRepository();
      final controller = WalletDetailController(repository: repository)
        ..wallet = _wallet;
      addTearDown(controller.onClose);

      final unlock = controller.unlockPrivateKey('password');
      controller.onPaused();
      repository.privateKeyCompleter.complete(_privateKey);

      expect(await unlock, isFalse);
      expect(controller.privateKeyText, isEmpty);
    },
  );
}

const _privateKey =
    '4f3edf983ac636a65a842ce7c78d9aa706d3b113bce036f3e28f5b778b4c1a2b';
const _mnemonic = 'test test test test test test test test test test test junk';
final _wallet = WalletAccount(
  id: 'wallet-1',
  name: 'Wallet 1',
  bscAddress: '0x1111111111111111111111111111111111111111',
  tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
  createdAt: DateTime(2026),
);

class _FakeWalletRepository extends WalletRepository {
  @override
  Future<String> readWalletPrivateKey({
    required String walletId,
    required String password,
  }) async => _privateKey;

  @override
  Future<String> readWalletMnemonic({
    required String walletId,
    required String password,
  }) async => _mnemonic;
}

class _DelayedWalletRepository extends _FakeWalletRepository {
  final Completer<String> privateKeyCompleter = Completer<String>();

  @override
  Future<String> readWalletPrivateKey({
    required String walletId,
    required String password,
  }) {
    return privateKeyCompleter.future;
  }
}
