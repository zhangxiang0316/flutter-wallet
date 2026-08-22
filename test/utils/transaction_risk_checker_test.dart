import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/transaction_risk_checker.dart';
import 'package:decimal/decimal.dart';

void main() {
  group('TransactionRiskChecker safety checks', () {
    test('uses exact decimal thresholds for large transfers', () {
      final below = TransactionRiskChecker.checkLargeAmount(
        amount: '0.499999999999999999',
        balance: '1',
        messageBuilder: (percentage) => 'large:$percentage',
      );
      final medium = TransactionRiskChecker.checkLargeAmount(
        amount: '0.500000000000000001',
        balance: '1',
        messageBuilder: (percentage) => 'large:$percentage',
      );
      final high = TransactionRiskChecker.checkLargeAmount(
        amount: '0.9',
        balance: '1',
        messageBuilder: (percentage) => 'large:$percentage',
      );

      expect(below, isNull);
      expect(medium?.level, RiskLevel.medium);
      expect(medium?.message, 'large:50');
      expect(high?.level, RiskLevel.high);
      expect(high?.message, 'large:90');
    });

    test(
      'only compares different fee assets when fiat values are available',
      () {
        final unavailable = TransactionRiskChecker.checkHighFee(
          fee: '1',
          amount: '1',
          feeSymbol: 'ETH',
          amountSymbol: 'USDC',
          messageBuilder: (percentage) => 'fee:$percentage',
        );
        final valued = TransactionRiskChecker.checkHighFee(
          fee: '0.01',
          amount: '100',
          feeSymbol: 'ETH',
          amountSymbol: 'USDC',
          feeFiatValue: Decimal.parse('20'),
          amountFiatValue: Decimal.parse('100'),
          messageBuilder: (percentage) => 'fee:$percentage',
        );

        expect(unavailable, isNull);
        expect(valued?.level, RiskLevel.high);
        expect(valued?.message, 'fee:20');
      },
    );

    test('compares same-symbol fee with Decimal instead of double', () {
      final risk = TransactionRiskChecker.checkHighFee(
        fee: '0.100000000000000001',
        amount: '1',
        feeSymbol: 'ETH',
        amountSymbol: 'eth',
        messageBuilder: (percentage) => 'fee:$percentage',
      );

      expect(risk?.level, RiskLevel.medium);
      expect(risk?.message, 'fee:10');
    });

    test('treats an empty chain history as a first-time recipient', () {
      final risk = TransactionRiskChecker.checkNewRecipient(
        address: 'TRecipient',
        historyAddresses: const [],
        message: 'new recipient',
        caseInsensitive: false,
      );

      expect(risk?.message, 'new recipient');
    });

    test('uses chain-specific address casing for recipient history', () {
      final evmRisk = TransactionRiskChecker.checkNewRecipient(
        address: '0xABC',
        historyAddresses: const ['0xabc'],
        message: 'new',
        caseInsensitive: true,
      );
      final solanaRisk = TransactionRiskChecker.checkNewRecipient(
        address: 'Abc',
        historyAddresses: const ['abc'],
        message: 'new',
        caseInsensitive: false,
      );

      expect(evmRisk, isNull);
      expect(solanaRisk, isNotNull);
    });

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

    test('detects Aptos zero burn address', () {
      final risk = TransactionRiskChecker.checkBurnAddress(
        recipientAddress:
            '0x0000000000000000000000000000000000000000000000000000000000000000',
        message: 'burn',
        isEvm: false,
        isSolana: false,
        isAptos: true,
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
