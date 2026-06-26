import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omnicast/wallet/services/wallet_backup_status_service.dart';

void main() {
  group('WalletBackupStatusService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('marks wallet mnemonic as backed up', () async {
      final service = WalletBackupStatusService();

      expect(await service.isMnemonicBackedUp('wallet-1'), isFalse);

      await service.markMnemonicBackedUp('wallet-1');

      expect(await service.isMnemonicBackedUp('wallet-1'), isTrue);
      expect(await service.isMnemonicBackedUp('wallet-2'), isFalse);
    });

    test('clears wallet mnemonic backup status', () async {
      final service = WalletBackupStatusService();

      await service.markMnemonicBackedUp('wallet-1');
      await service.markMnemonicBackedUp('wallet-2');
      await service.clearMnemonicBackedUp('wallet-1');

      expect(await service.isMnemonicBackedUp('wallet-1'), isFalse);
      expect(await service.isMnemonicBackedUp('wallet-2'), isTrue);
    });
  });
}
