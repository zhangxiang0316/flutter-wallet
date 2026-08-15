import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';

void main() {
  test('persists Bitcoin addresses and keeps old wallets compatible', () {
    final createdAt = DateTime.utc(2026, 8, 15);
    final wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Wallet 1',
      bscAddress: '0x1111111111111111111111111111111111111111',
      tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
      solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      bitcoinAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      createdAt: createdAt,
    );

    final decoded = WalletAccount.fromJson(wallet.toJson());
    final legacy = WalletAccount.fromJson({
      'id': 'wallet-2',
      'name': 'Legacy',
      'bscAddress': '0x2222222222222222222222222222222222222222',
      'tronAddress': 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
      'createdAt': createdAt.toIso8601String(),
    });

    expect(decoded.bitcoinAddress, wallet.bitcoinAddress);
    expect(legacy.bitcoinAddress, isEmpty);
  });
}
