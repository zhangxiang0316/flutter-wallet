import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_asset_identity_policy.dart';

void main() {
  group('WalletCanonicalToken', () {
    test('normalizes explicitly assigned canonical IDs', () {
      expect(WalletCanonicalToken.normalizeId(' USDC '), 'usdc');
      expect(
        WalletCanonicalToken.normalizeId('custom.token-1'),
        'custom.token-1',
      );
    });

    test('rejects empty or unsafe canonical IDs', () {
      expect(WalletCanonicalToken.normalizeId(''), isNull);
      expect(WalletCanonicalToken.normalizeId('USDC token'), isNull);
      expect(WalletCanonicalToken.normalizeId('../usdc'), isNull);
    });

    test('resolves built-in token metadata by normalized ID', () {
      final token = WalletCanonicalToken.fromId(' USDC ');

      expect(token?.symbol, 'USDC');
      expect(token?.name, 'USD Coin');
      expect(WalletCanonicalToken.fromId('custom-token'), isNull);
    });
  });
}
