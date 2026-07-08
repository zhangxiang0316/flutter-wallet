import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/services/crypto/wallet_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletSecretStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('encrypts private keys and rejects invalid passwords', () async {
      const privateKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final store = WalletSecretStore();

      await store.savePrivateKey(
        walletId: 'wallet-1',
        password: 'secret123',
        privateKeyHex: privateKey,
      );
      await store.saveMnemonic(
        walletId: 'wallet-1',
        password: 'secret123',
        mnemonic: mnemonic,
      );

      expect(await store.hasPrivateKey('wallet-1'), isTrue);
      expect(await store.hasMnemonic('wallet-1'), isTrue);
      expect(
        await store.readPrivateKey(walletId: 'wallet-1', password: 'secret123'),
        privateKey,
      );
      expect(
        await store.readMnemonic(walletId: 'wallet-1', password: 'secret123'),
        mnemonic,
      );
      expect(
        () => store.readPrivateKey(walletId: 'wallet-1', password: 'wrong'),
        throwsA(isA<WalletSecretInvalidPasswordException>()),
      );

      final rawStorage = await const FlutterSecureStorage().readAll();
      expect(rawStorage.values.join(), isNot(contains(privateKey)));
      expect(rawStorage.values.join(), isNot(contains(mnemonic)));
    });

    test('throws missing exception when mnemonic was never stored', () async {
      final store = WalletSecretStore();

      await store.savePrivateKey(
        walletId: 'wallet-1',
        password: 'secret123',
        privateKeyHex:
            '0000000000000000000000000000000000000000000000000000000000000001',
      );

      expect(await store.hasMnemonic('wallet-1'), isFalse);
      expect(
        () => store.readMnemonic(walletId: 'wallet-1', password: 'secret123'),
        throwsA(isA<WalletSecretMissingException>()),
      );
    });

    test(
      'throws corrupted exception for malformed encrypted payload',
      () async {
        const walletId = 'wallet-1';
        final storageKey =
            'wallet_secret_${base64Url.encode(utf8.encode(walletId))}';

        await const FlutterSecureStorage().write(
          key: storageKey,
          value: 'not-json',
        );

        expect(
          () => WalletSecretStore().readPrivateKey(
            walletId: walletId,
            password: 'secret123',
          ),
          throwsA(isA<WalletSecretCorruptedException>()),
        );
      },
    );
  });
}
