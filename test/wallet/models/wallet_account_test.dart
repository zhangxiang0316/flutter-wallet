import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletAccount', () {
    test('does not serialize private keys to plain storage', () {
      final wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet 1',
        bscAddress: '0x1',
        tronAddress: 'T1',
        createdAt: DateTime.utc(2026),
        privateKeyHex: 'legacy-private-key',
      );

      expect(wallet.needsSecretMigration, isTrue);
      expect(wallet.toJson().containsKey('privateKeyHex'), isFalse);
    });
  });
}
