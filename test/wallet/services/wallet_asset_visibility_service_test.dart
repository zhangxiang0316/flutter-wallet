import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/config/wallet_asset_visibility_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migrates legacy dynamic Polygon hidden asset keys', () async {
    SharedPreferences.setMockInitialValues({
      'wallet_hidden_assets': jsonEncode([
        'evm-137:native:MATIC',
        'evm-137:0x3c499c542cef5e3811e1192ce70d8cc03d5c3359:USDC',
        'base:native:ETH',
      ]),
    });
    final service = WalletAssetVisibilityService();

    final keys = await service.loadHiddenAssetKeys();

    expect(keys, contains('polygon:native:POL'));
    expect(
      keys,
      contains('polygon:0x3c499c542cef5e3811e1192ce70d8cc03d5c3359:USDC'),
    );
    expect(keys, contains('base:native:ETH'));
    expect(keys.any((key) => key.startsWith('evm-137:')), isFalse);
  });

  test('migrates legacy dynamic Avalanche hidden asset keys', () async {
    SharedPreferences.setMockInitialValues({
      'wallet_hidden_assets': jsonEncode([
        'evm-43114:native:AVAX',
        'evm-43114:0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e:USDC',
        'avalanche:0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7:USDT',
        'ethereum:native:ETH',
      ]),
    });
    final service = WalletAssetVisibilityService();

    final keys = await service.loadHiddenAssetKeys();

    expect(keys, contains('avalanche:native:AVAX'));
    expect(
      keys,
      contains('avalanche:0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e:USDC'),
    );
    expect(
      keys,
      contains('avalanche:0x9702230a8ea53601f5cd2dc00fdbc13d4df4a8c7:USDT'),
    );
    expect(keys, contains('ethereum:native:ETH'));
    expect(keys.any((key) => key.startsWith('evm-43114:')), isFalse);
    expect(
      service.isBalanceVisible(
        const ChainBalance(
          chain: WalletChain.avalanche,
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '0',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
          decimals: 6,
        ),
        keys,
      ),
      isFalse,
    );
  });
}
