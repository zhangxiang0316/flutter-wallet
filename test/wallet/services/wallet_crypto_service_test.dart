import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletCryptoService', () {
    late WalletCryptoService service;

    setUp(() {
      service = WalletCryptoService();
    });

    test(
      'derives EVM, Solana, TRON, and Bitcoin addresses from a private key',
      () {
        final keyPair = service.importPrivateKey(
          '0x0000000000000000000000000000000000000000000000000000000000000001',
        );

        expect(
          keyPair.bscAddress,
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        );
        expect(keyPair.tronAddress, 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC');
        expect(keyPair.bitcoinAddress, startsWith('bc1q'));
        expect(
          WalletTransferService.normalizeSolanaAddress(keyPair.solanaAddress),
          keyPair.solanaAddress,
        );
      },
    );

    test('generates and imports mnemonic wallets deterministically', () {
      final mnemonic = service.generateMnemonic();
      expect(mnemonic.split(' '), hasLength(12));

      final first = service.importMnemonic(mnemonic);
      final second = service.importMnemonic(mnemonic);

      expect(first.mnemonic, mnemonic);
      expect(first.privateKeyHex, second.privateKeyHex);
      expect(first.bscAddress, second.bscAddress);
      expect(first.tronAddress, second.tronAddress);
      expect(first.solanaAddress, second.solanaAddress);
      expect(first.bitcoinAddress, second.bitcoinAddress);
      expect(
        WalletTransferService.normalizeSolanaAddress(first.solanaAddress),
        first.solanaAddress,
      );
    });

    test('matches the BIP84 first receiving address test vector', () {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon about';

      final keyPair = service.importMnemonic(mnemonic);

      expect(
        keyPair.bitcoinAddress,
        'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );
      expect(
        service.bitcoinAddressFromPrivateKey(
          service.bitcoinPrivateKeyFromMnemonic(mnemonic),
        ),
        keyPair.bitcoinAddress,
      );
    });

    test('derives Solana signing seed from mnemonic and private key', () {
      final mnemonic = service.generateMnemonic();
      final keyPair = service.importMnemonic(mnemonic);
      final mnemonicSeed = service.solanaPrivateKeyFromMnemonic(mnemonic);
      final privateKeySeed = service.solanaPrivateKeyFromPrivateKey(
        keyPair.privateKeyHex,
      );

      expect(mnemonicSeed, hasLength(32));
      expect(privateKeySeed, hasLength(32));
      expect(
        service.importPrivateKey(keyPair.privateKeyHex).solanaAddress,
        isNotEmpty,
      );
    });

    test('rejects malformed private keys', () {
      expect(() => service.importPrivateKey('abc'), throwsFormatException);
      expect(
        () => service.importPrivateKey(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed mnemonics', () {
      expect(
        () => service.importMnemonic('alpha beta gamma'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
