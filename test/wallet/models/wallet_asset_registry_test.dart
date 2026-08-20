import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletAssetRegistry', () {
    test('serializes custom assets and merges them by contract address', () {
      const customAsset = WalletAsset(
        chain: WalletChain.bsc,
        symbol: 'CAKE',
        name: 'PancakeSwap Token',
        decimals: 18,
        contractAddress: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
        logoUrl: 'https://example.com/cake.png',
        isCustom: true,
      );

      final decoded = WalletAsset.fromJson(customAsset.toJson());
      final merged = WalletAssetRegistry.mergeCustomAssets(WalletChain.bsc, [
        decoded,
        const WalletAsset(
          chain: WalletChain.bsc,
          symbol: 'CAKE2',
          name: 'Duplicate',
          decimals: 18,
          contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
          isCustom: true,
        ),
      ]);

      expect(decoded.isCustom, isTrue);
      expect(decoded.symbol, 'CAKE');
      expect(decoded.logoUrl, 'https://example.com/cake.png');
      expect(
        merged.where(
          (asset) => asset.contractAddress == decoded.contractAddress,
        ),
        hasLength(1),
      );
    });

    test('creates native asset for custom EVM chains', () {
      final chain = WalletChainConfig.customEvm(
        id: 'evm-137',
        name: 'Polygon',
        symbol: 'MATIC',
        rpcUrls: const ['https://polygon-rpc.com'],
        evmChainId: 137,
      );

      final assets = WalletAssetRegistry.mergeCustomAssetsForChainConfig(
        chain,
        const [],
      );

      expect(assets, hasLength(1));
      expect(assets.first.chainId, 'evm-137');
      expect(assets.first.symbol, 'MATIC');
      expect(assets.first.isNative, isTrue);
    });

    test('migrates the existing Polygon USDC to the USDC home group', () {
      final asset = WalletAsset.fromJson(const {
        'chainId': 'evm-137',
        'chainName': 'Polygon',
        'chainSymbol': 'MATIC',
        'evmChainId': 137,
        'symbol': 'USDC',
        'name': 'USD Coin',
        'decimals': 6,
        'contractAddress': '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
        'isCustom': true,
      });

      expect(asset.canonicalTokenId, 'usdc');
      expect(asset.toJson()['canonicalTokenId'], 'usdc');
    });

    test('provides Polygon native and common mapped assets', () {
      final assets = WalletAssetRegistry.assetsForChain(WalletChain.polygon);

      expect(assets.first.symbol, 'POL');
      expect(assets.first.isNative, isTrue);
      expect(assets.first.canonicalTokenId, 'pol');
      expect(
        assets.singleWhere((asset) => asset.symbol == 'USDC').contractAddress,
        '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
      );
      expect(
        assets.singleWhere((asset) => asset.symbol == 'WETH').canonicalTokenId,
        'eth',
      );
      expect(
        assets.singleWhere((asset) => asset.symbol == 'WBTC').canonicalTokenId,
        'btc',
      );
    });

    test('keeps arbitrary user-defined canonical token IDs', () {
      const asset = WalletAsset(
        chain: WalletChain.bsc,
        symbol: 'DAI',
        name: 'Dai Stablecoin',
        decimals: 18,
        contractAddress: '0x1111111111111111111111111111111111111111',
        canonicalTokenId: 'dai',
        isCustom: true,
      );

      expect(WalletAsset.fromJson(asset.toJson()).canonicalTokenId, 'dai');
    });
  });
}
