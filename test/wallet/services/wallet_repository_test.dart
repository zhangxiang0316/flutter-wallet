import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/storage.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('migrates legacy plain private key into secure storage', () async {
      const privateKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final storage = Storage();
      final repository = WalletRepository(storage: storage);

      await storage.setJsonMap('crypto_wallet_account', {
        'id': 'wallet-1',
        'name': 'Legacy Wallet',
        'bscAddress': '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        'tronAddress': 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        'solanaAddress': '',
        'privateKeyHex': privateKey,
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });

      expect(await repository.hasLegacyPlainSecrets(), isTrue);

      await repository.migrateLegacyPlainSecrets('wallet-password');

      final wallets = await repository.loadWallets();
      expect(wallets, hasLength(1));
      expect(wallets.single.needsSecretMigration, isFalse);
      expect(await storage.getJsonMap('crypto_wallet_account'), isNull);
      expect(
        await repository.readWalletPrivateKey(
          walletId: 'wallet-1',
          password: 'wallet-password',
        ),
        privateKey,
      );
      expect(await repository.hasLegacyPlainSecrets(), isFalse);
    });

    test('derives the Bitcoin signing key from a stored mnemonic', () async {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';
      const password = 'wallet-password';
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importMnemonic(mnemonic);
      final repository = WalletRepository(cryptoService: cryptoService);

      await repository.saveWalletSecret(
        walletId: 'wallet-1',
        password: password,
        privateKeyHex: keyPair.privateKeyHex,
        mnemonic: mnemonic,
      );

      final bitcoinPrivateKey = await repository.readWalletBitcoinPrivateKey(
        walletId: 'wallet-1',
        password: password,
      );
      expect(
        cryptoService.bitcoinAddressFromPrivateKey(bitcoinPrivateKey),
        keyPair.bitcoinAddress,
      );
    });
  });
}
