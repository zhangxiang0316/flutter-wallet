import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/config/wallet_custom_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletCustomAssetService', () {
    test('builds manually added assets with normalized EVM addresses', () {
      final service = WalletCustomAssetService();
      final asset = service.buildManualAsset(
        chain: WalletChain.bsc.config,
        contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
        symbol: 'cake',
        name: 'PancakeSwap Token',
        decimals: 18,
        logoUrl: 'https://example.com/cake.png',
      );

      expect(asset.symbol, 'CAKE');
      expect(
        asset.contractAddress,
        '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
      );
      expect(asset.logoUrl, 'https://example.com/cake.png');
      expect(asset.isCustom, isTrue);
    });

    test('rejects invalid custom asset logo URLs', () {
      final service = WalletCustomAssetService();

      expect(
        () => service.buildManualAsset(
          chain: WalletChain.bsc.config,
          contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
          symbol: 'cake',
          name: 'PancakeSwap Token',
          decimals: 18,
          logoUrl: 'javascript:alert(1)',
        ),
        throwsA(isA<CustomAssetInvalidInputException>()),
      );
    });

    test('provides popular assets for supported chains', () {
      final assets = WalletCustomAssetService.popularAssetsForChain(
        WalletChain.ethereum.config,
      );

      expect(assets.map((asset) => asset.symbol), contains('WETH'));
      expect(assets.first.logoUrl, isNotEmpty);
      expect(assets.every((asset) => asset.isCustom), isTrue);
    });
  });
}
