import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/constants/crypto_constants.dart';

void main() {
  group('CryptoConstants', () {
    test('base58Alphabet has correct length', () {
      expect(CryptoConstants.base58Alphabet.length, equals(58));
    });

    test('base58Alphabet contains expected characters', () {
      // Should not contain 0, O, I, l (confusing characters)
      expect(CryptoConstants.base58Alphabet.contains('0'), isFalse);
      expect(CryptoConstants.base58Alphabet.contains('O'), isFalse);
      expect(CryptoConstants.base58Alphabet.contains('I'), isFalse);
      expect(CryptoConstants.base58Alphabet.contains('l'), isFalse);

      // Should start with '1'
      expect(CryptoConstants.base58Alphabet[0], equals('1'));
    });

    test('derivation paths follow BIP44 standard', () {
      // EVM path: m/44'/60'/0'/0/0
      expect(CryptoConstants.evmDerivationPath, equals("m/44'/60'/0'/0/0"));

      // Solana path: m/44'/501'/0'/0'
      expect(CryptoConstants.solanaDerivationPath, equals("m/44'/501'/0'/0'"));
    });

    test('gas limits have reasonable values', () {
      // EVM native transfer
      expect(CryptoConstants.evmNativeGasLimit, equals(21000));

      // EVM token transfer
      expect(CryptoConstants.evmTokenGasLimit, equals(100000));

      // TRON token fee limit
      expect(CryptoConstants.tronTokenFeeLimit, equals(30000000));

      // Solana signature fee
      expect(CryptoConstants.solanaLamportsPerSignature, equals(5000));
    });

    test('secp256k1P is correct prime', () {
      final expectedP = BigInt.parse(
        'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
        radix: 16,
      );
      expect(CryptoConstants.secp256k1P, equals(expectedP));
    });

    test('evmTransferEventTopic is correct', () {
      // keccak256("Transfer(address,address,uint256)")
      expect(
        CryptoConstants.evmTransferEventTopic,
        equals('0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'),
      );
    });
  });
}
