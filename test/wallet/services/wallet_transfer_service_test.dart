import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';

void main() {
  group('WalletTransferService', () {
    group('Address validation', () {
      test('normalizeEvmAddress accepts valid lowercase address', () {
        const address = '0x742d35cc6634c0532925a3b844bc9e7595f0beb5';
        final result = WalletTransferService.normalizeEvmAddress(address);
        expect(result, equals(address));
      });

      test('normalizeEvmAddress converts uppercase to lowercase', () {
        const address = '0x742D35CC6634C0532925A3B844BC9E7595F0BEB5';
        final result = WalletTransferService.normalizeEvmAddress(address);
        expect(result, equals('0x742d35cc6634c0532925a3b844bc9e7595f0beb5'));
      });

      test('normalizeEvmAddress validates EIP-55 checksum', () {
        // Valid checksum address
        const validAddress = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';
        expect(
          () => WalletTransferService.normalizeEvmAddress(validAddress),
          returnsNormally,
        );

        // Invalid checksum (changed one letter case)
        const invalidAddress = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1Beaed';
        expect(
          () => WalletTransferService.normalizeEvmAddress(invalidAddress),
          throwsA(isA<FormatException>()),
        );
      });

      test('normalizeEvmAddress rejects invalid format', () {
        expect(
          () => WalletTransferService.normalizeEvmAddress('invalid'),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => WalletTransferService.normalizeEvmAddress('0x123'),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => WalletTransferService.normalizeEvmAddress('742d35cc6634c0532925a3b844bc9e7595f0beb5'),
          throwsA(isA<FormatException>()),
        );
      });

      test('tronAddressToHex validates TRON address format', () {
        // Test invalid format
        expect(
          () => WalletTransferService.tronAddressToHex('invalid'),
          throwsA(isA<FormatException>()),
        );

        // Test address too short
        expect(
          () => WalletTransferService.tronAddressToHex('TRX'),
          throwsA(isA<FormatException>()),
        );
      });

      test('normalizeSolanaAddress validates Solana address', () {
        // Valid Solana address
        const validAddress = '7EqQdEUHxbf7pKPQiJKKCJVJeVVhJZCfE6xBx7KfqhAd';
        expect(
          () => WalletTransferService.normalizeSolanaAddress(validAddress),
          returnsNormally,
        );

        // Invalid address
        expect(
          () => WalletTransferService.normalizeSolanaAddress('invalid'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('Amount conversion', () {
      test('amountToRawUnits converts decimal to raw units', () {
        // 1.5 tokens with 18 decimals
        final result = WalletTransferService.amountToRawUnits('1.5', 18);
        expect(result, equals(BigInt.parse('1500000000000000000')));

        // 100 tokens with 6 decimals
        final result2 = WalletTransferService.amountToRawUnits('100', 6);
        expect(result2, equals(BigInt.from(100000000)));

        // 0.000001 tokens with 18 decimals
        final result3 = WalletTransferService.amountToRawUnits('0.000001', 18);
        expect(result3, equals(BigInt.from(1000000000000)));
      });

      test('amountToRawUnits rejects invalid amounts', () {
        expect(
          () => WalletTransferService.amountToRawUnits('invalid', 18),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => WalletTransferService.amountToRawUnits('-1', 18),
          throwsA(isA<FormatException>()),
        );

        expect(
          () => WalletTransferService.amountToRawUnits('0', 18),
          throwsA(isA<FormatException>()),
        );
      });

      test('amountToRawUnits handles max precision', () {
        // 18 decimal places (max for most tokens)
        final result = WalletTransferService.amountToRawUnits(
          '0.123456789012345678',
          18,
        );
        expect(result, equals(BigInt.parse('123456789012345678')));
      });
    });

    group('ERC20 transfer data', () {
      test('erc20TransferData generates correct data', () {
        const toAddress = '0x742d35cc6634c0532925a3b844bc9e7595f0beb5';
        final amount = BigInt.parse('1000000000000000000'); // 1 token

        final data = WalletTransferService.erc20TransferData(toAddress, amount);

        // Should start with transfer function selector
        expect(data.startsWith('0xa9059cbb'), isTrue);

        // Should have correct length (10 + 64 + 64 characters)
        expect(data.length, equals(138));
      });
    });
  });
}
