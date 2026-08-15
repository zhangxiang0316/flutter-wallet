import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/transaction_risk_checker.dart';

void main() {
  group('TransactionRiskChecker safety checks', () {
    test('detects self transfer with case-insensitive EVM addresses', () {
      final risk = TransactionRiskChecker.checkSelfTransfer(
        recipientAddress: '0x742D35CC6634C0532925A3B844BC9E7595F0BEB5',
        walletAddress: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
        message: 'self',
        caseInsensitive: true,
      );

      expect(risk, isNotNull);
      expect(risk!.level, RiskLevel.medium);
    });

    test('detects token contract recipient', () {
      final risk = TransactionRiskChecker.checkTokenContractRecipient(
        recipientAddress: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x1111111111111111111111111111111111111111',
        message: 'contract',
        caseInsensitive: true,
      );

      expect(risk, isNotNull);
      expect(risk!.level, RiskLevel.high);
    });

    test('detects EVM burn address', () {
      final risk = TransactionRiskChecker.checkBurnAddress(
        recipientAddress: '0x000000000000000000000000000000000000dEaD',
        message: 'burn',
        isEvm: true,
        isSolana: false,
      );

      expect(risk, isNotNull);
      expect(risk!.level, RiskLevel.high);
    });

    test('detects Sui zero burn address', () {
      final risk = TransactionRiskChecker.checkBurnAddress(
        recipientAddress:
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        message: 'burn',
        isEvm: false,
        isSolana: false,
        isSui: true,
      );

      expect(risk, isNotNull);
      expect(risk!.level, RiskLevel.high);
    });

    test('detects clipboard mismatch', () {
      final risk = TransactionRiskChecker.checkClipboardMismatch(
        recipientAddress: '0x1111111111111111111111111111111111111111',
        clipboardAddress: '0x2222222222222222222222222222222222222222',
        message: 'mismatch',
        caseInsensitive: true,
      );

      expect(risk, isNotNull);
      expect(risk!.level, RiskLevel.medium);
    });

    test('ignores matching clipboard address', () {
      final risk = TransactionRiskChecker.checkClipboardMismatch(
        recipientAddress: '0x1111111111111111111111111111111111111111',
        clipboardAddress: '0x1111111111111111111111111111111111111111',
        message: 'mismatch',
        caseInsensitive: true,
      );

      expect(risk, isNull);
    });
  });
}
