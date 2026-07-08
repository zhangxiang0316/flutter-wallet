import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/transaction/transaction_history_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionHistoryCache local records', () {
    test(
      'upserts local pending records and preserves updated status',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cache = TransactionHistoryCache();
        final record = WalletTransactionRecord(
          id: 'local:wallet:bsc:0xabc',
          walletId: 'wallet',
          chainId: 'bsc',
          chainName: 'BNB Smart Chain',
          symbol: 'BNB',
          assetName: 'BNB',
          walletAddress: '0x1111111111111111111111111111111111111111',
          txHash: '0xabc',
          fromAddress: '0x1111111111111111111111111111111111111111',
          toAddress: '0x2222222222222222222222222222222222222222',
          amount: '1',
          decimals: 18,
          direction: WalletTransactionDirection.outgoing,
          status: WalletTransactionStatus.pending,
          source: WalletTransactionSource.local,
          timestamp: DateTime.utc(2026),
        );

        await cache.upsertLocalRecord(record);
        await cache.upsertLocalRecord(
          record.copyWith(status: WalletTransactionStatus.success),
        );

        final records = await cache.loadLocalRecords('wallet', 'bsc', 'BNB');

        expect(records, hasLength(1));
        expect(records.single.status, WalletTransactionStatus.success);
        expect(records.single.toAddress, record.toAddress);
      },
    );
  });

  group('TransactionHistoryCache remote records', () {
    test(
      'falls back to non-empty legacy cache when contract cache is empty',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cache = TransactionHistoryCache();
        final record = WalletTransactionRecord(
          id: 'remote:wallet:arbitrum:USDC:0xabc',
          walletId: 'wallet',
          chainId: 'arbitrum',
          chainName: 'Arbitrum',
          symbol: 'USDC',
          assetName: 'USD Coin',
          walletAddress: '0x1111111111111111111111111111111111111111',
          txHash: '0xabc',
          fromAddress: '0x1111111111111111111111111111111111111111',
          toAddress: '0x2222222222222222222222222222222222222222',
          amount: '50.505051',
          decimals: 6,
          direction: WalletTransactionDirection.outgoing,
          status: WalletTransactionStatus.success,
          source: WalletTransactionSource.remote,
          contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
          timestamp: DateTime.utc(2026),
        );
        final encodedLegacy = jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'records': [record.toJson()],
        });
        final encodedEmptyCurrent = jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'records': <Object>[],
        });
        await prefs.setString(
          'tx_history_v1_wallet_arbitrum_USDC',
          encodedLegacy,
        );
        await prefs.setString(
          'tx_history_v1_wallet_arbitrum_'
          '0xaf88d065e77c8cc2239327c5edb3a432268e5831_USDC',
          encodedEmptyCurrent,
        );

        final records = await cache.load(
          'wallet',
          'arbitrum',
          'USDC',
          contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
        );

        expect(records, hasLength(1));
        expect(records!.single.txHash, '0xabc');
      },
    );

    test('keeps stale non-empty remote history as fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = TransactionHistoryCache();
      final record = WalletTransactionRecord(
        id: 'remote:wallet:arbitrum:USDC:0xstale',
        walletId: 'wallet',
        chainId: 'arbitrum',
        chainName: 'Arbitrum',
        symbol: 'USDC',
        assetName: 'USD Coin',
        walletAddress: '0x1111111111111111111111111111111111111111',
        txHash: '0xstale',
        fromAddress: '0x1111111111111111111111111111111111111111',
        toAddress: '0x2222222222222222222222222222222222222222',
        amount: '50.505051',
        decimals: 6,
        direction: WalletTransactionDirection.outgoing,
        status: WalletTransactionStatus.success,
        source: WalletTransactionSource.remote,
        contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
        timestamp: DateTime.utc(2026),
      );
      final encodedStale = jsonEncode({
        'timestamp': DateTime.now()
            .subtract(const Duration(days: 10))
            .toIso8601String(),
        'records': [record.toJson()],
      });
      await prefs.setString(
        'tx_history_v1_wallet_arbitrum_'
        '0xaf88d065e77c8cc2239327c5edb3a432268e5831_USDC',
        encodedStale,
      );

      final records = await cache.load(
        'wallet',
        'arbitrum',
        'USDC',
        contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
      );

      expect(records, hasLength(1));
      expect(records!.single.txHash, '0xstale');
    });
  });
}
