import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
