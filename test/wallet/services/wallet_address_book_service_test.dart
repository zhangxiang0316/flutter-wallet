import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omnicast/wallet/services/config/wallet_address_book_service.dart';

void main() {
  group('WalletAddressBookService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads entries ordered by update time', () async {
      final service = WalletAddressBookService();

      await service.saveEntry(
        name: 'Alice',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
        chainId: 'ethereum',
        chainName: 'Ethereum',
      );
      await service.saveEntry(
        name: 'Bob',
        address: 'TQn9Y2khEsLJW1ChVWFMSMeRDow5KcbLSE',
        chainId: 'tron',
        chainName: 'TRON',
      );

      final entries = await service.loadEntries();

      expect(entries, hasLength(2));
      expect(entries.first.name, equals('Bob'));
      expect(entries.last.name, equals('Alice'));
    });

    test('filters entries by chain id', () async {
      final service = WalletAddressBookService();

      await service.saveEntry(
        name: 'ETH Contact',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
        chainId: 'ethereum',
        chainName: 'Ethereum',
      );
      await service.saveEntry(
        name: 'BSC Contact',
        address: '0x1111111111111111111111111111111111111111',
        chainId: 'bsc',
        chainName: 'BNB Smart Chain',
      );

      final entries = await service.loadEntriesForChain('bsc');

      expect(entries, hasLength(1));
      expect(entries.single.name, equals('BSC Contact'));
    });

    test('updates and removes entries', () async {
      final service = WalletAddressBookService();

      await service.saveEntry(
        name: 'Alice',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
        chainId: 'ethereum',
        chainName: 'Ethereum',
      );
      final initial = await service.loadEntries();

      await service.saveEntry(
        id: initial.single.id,
        name: 'Alice Cold Wallet',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
        chainId: 'ethereum',
        chainName: 'Ethereum',
        note: 'backup',
      );
      final updated = await service.loadEntries();

      expect(updated, hasLength(1));
      expect(updated.single.name, equals('Alice Cold Wallet'));
      expect(updated.single.note, equals('backup'));

      await service.removeEntry(updated.single.id);
      expect(await service.loadEntries(), isEmpty);
    });
  });
}
