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
      'derives EVM, Solana, Sui, TRON, and Bitcoin addresses from a private key',
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
          WalletTransferService.normalizeSuiAddress(keyPair.suiAddress),
          keyPair.suiAddress,
        );
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
      expect(first.suiAddress, second.suiAddress);
      expect(first.bitcoinAddress, second.bitcoinAddress);
      expect(
        WalletTransferService.normalizeSolanaAddress(first.solanaAddress),
        first.solanaAddress,
      );
    });

    test('matches the Sui Ed25519 derivation test vector', () {
      const mnemonic =
          'result crisp session latin must fruit genuine question prevent '
          'start coconut brave speak student dismiss';

      final keyPair = service.importMnemonic(mnemonic);

      expect(
        keyPair.suiAddress,
        '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973',
      );
      expect(
        service.suiAddressFromPrivateKey(
          service.suiPrivateKeyFromMnemonic(mnemonic),
        ),
        keyPair.suiAddress,
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

    test('derives Sui signing seed from mnemonic and private key', () {
      final mnemonic = service.generateMnemonic();
      final keyPair = service.importMnemonic(mnemonic);
      final mnemonicSeed = service.suiPrivateKeyFromMnemonic(mnemonic);
      final privateKeySeed = service.suiPrivateKeyFromPrivateKey(
        keyPair.privateKeyHex,
      );

      expect(mnemonicSeed, hasLength(32));
      expect(privateKeySeed, hasLength(32));
      expect(
        service.suiAddressFromPrivateKey(mnemonicSeed),
        keyPair.suiAddress,
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
