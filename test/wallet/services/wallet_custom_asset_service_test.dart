import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/config/wallet_custom_asset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WalletCustomAssetService', () {
    test('builds manually added assets with normalized EVM addresses', () {
      final service = WalletCustomAssetService();
      final asset = service.buildManualAsset(
        chain: WalletChain.bsc.config,
        contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
        symbol: 'cake',
        name: 'PancakeSwap Token',
        decimals: 18,
        metadataVerified: true,
        logoUrl: 'https://example.com/cake.png',
        canonicalTokenId: 'cake',
      );

      expect(asset.symbol, 'CAKE');
      expect(
        asset.contractAddress,
        '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
      );
      expect(asset.logoUrl, 'https://example.com/cake.png');
      expect(asset.canonicalTokenId, 'cake');
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
          metadataVerified: true,
          logoUrl: 'javascript:alert(1)',
        ),
        throwsA(isA<CustomAssetInvalidInputException>()),
      );
    });

    test('requires verified metadata for manually added EVM assets', () {
      final service = WalletCustomAssetService();

      expect(
        () => service.buildManualAsset(
          chain: WalletChain.bsc.config,
          contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
          symbol: 'cake',
          name: 'PancakeSwap Token',
          decimals: 18,
        ),
        throwsA(isA<CustomAssetUnverifiedMetadataException>()),
      );
    });

    test('keeps saved token decimals immutable', () async {
      final service = WalletCustomAssetService();
      final asset = WalletAsset.config(
        chainConfig: WalletChain.bsc.config,
        symbol: 'CAKE',
        name: 'PancakeSwap Token',
        decimals: 18,
        contractAddress: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
        isCustom: true,
      );
      await service.saveCustomAssets([asset]);

      final modified = WalletAsset.config(
        chainConfig: WalletChain.bsc.config,
        symbol: 'CAKE',
        name: 'PancakeSwap Token',
        decimals: 6,
        contractAddress: asset.contractAddress,
        isCustom: true,
      );
      await expectLater(
        service.saveCustomAssets([modified]),
        throwsA(isA<CustomAssetDecimalsImmutableException>()),
      );
    });

    test('provides popular assets for supported chains', () {
      final assets = WalletCustomAssetService.popularAssetsForChain(
        WalletChain.ethereum.config,
      );

      expect(assets.map((asset) => asset.symbol), contains('WETH'));
      expect(assets.first.logoUrl, isNotEmpty);
      expect(assets.first.canonicalTokenId, 'weth');
      expect(assets.every((asset) => asset.isCustom), isTrue);

      final polygonAssets = WalletCustomAssetService.popularAssetsForChain(
        WalletChain.polygon.config,
      );
      expect(polygonAssets.map((asset) => asset.symbol), contains('DAI'));
      expect(polygonAssets.single.logoUrl, contains('/blockchains/polygon/'));

      final avalancheAssets = WalletCustomAssetService.popularAssetsForChain(
        WalletChain.avalanche.config,
      );
      expect(avalancheAssets.map((asset) => asset.symbol), contains('WAVAX'));
      expect(
        avalancheAssets.single.logoUrl,
        contains('/blockchains/avalanchec/'),
      );
    });

    test('persists the Polygon USDC canonical identity migration', () async {
      final polygon = WalletChainConfig.customEvm(
        id: 'evm-137',
        name: 'Polygon',
        symbol: 'MATIC',
        rpcUrls: const ['https://polygon-rpc.example'],
        evmChainId: 137,
      );
      SharedPreferences.setMockInitialValues({
        'wallet_custom_evm_chains': jsonEncode([polygon.toJson()]),
        'wallet_custom_assets': jsonEncode([
          {
            'chainId': 'evm-137',
            'chainName': 'Polygon',
            'chainSymbol': 'MATIC',
            'evmChainId': 137,
            'symbol': 'USDC',
            'name': 'USD Coin',
            'decimals': 6,
            'contractAddress': '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
            'canonicalTokenId': null,
            'isCustom': true,
          },
        ]),
      });

      final assets = await WalletCustomAssetService().loadCustomAssets();
      final stored =
          jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  'wallet_custom_assets',
                )!,
              )
              as List<dynamic>;
      final storedChains =
          jsonDecode(
                (await SharedPreferences.getInstance()).getString(
                  'wallet_custom_evm_chains',
                )!,
              )
              as List<dynamic>;

      expect(assets.single.chainId, WalletChain.polygon.id);
      expect(assets.single.chainRef.symbol, 'POL');
      expect(assets.single.canonicalTokenId, 'usdc');
      expect(
        (stored.single as Map<String, dynamic>)['chainId'],
        WalletChain.polygon.id,
      );
      expect(
        (stored.single as Map<String, dynamic>)['canonicalTokenId'],
        'usdc',
      );
      expect(storedChains, isEmpty);
    });
  });
}
