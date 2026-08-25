import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  group('WalletAsset serialization', () {
    test('round-trips custom chain metadata', () {
      final chain = WalletChainConfig.customEvm(
        id: 'evm-9001',
        name: 'Custom EVM',
        symbol: 'CETH',
        rpcUrls: const ['https://rpc.example.com'],
        evmChainId: 9001,
      );
      final source = WalletAsset.config(
        chainConfig: chain,
        symbol: 'USDC',
        name: 'USD Coin',
        decimals: 6,
        contractAddress: '0x1111111111111111111111111111111111111111',
        logoUrl: 'https://example.com/usdc.png',
        canonicalTokenId: 'usdc',
        isCustom: true,
      );

      final decoded = WalletAsset.fromJson(source.toJson());

      expect(decoded.chainId, source.chainId);
      expect(decoded.chainRef.evmChainId, 9001);
      expect(decoded.symbol, source.symbol);
      expect(decoded.decimals, source.decimals);
      expect(decoded.contractAddress, source.contractAddress);
      expect(decoded.logoUrl, source.logoUrl);
      expect(decoded.canonicalTokenId, source.canonicalTokenId);
      expect(decoded.isCustom, isTrue);
    });

    test('migrates legacy Polygon USDC identity', () {
      final asset = WalletAsset.fromJson(const {
        'chainId': 'evm-137',
        'chainName': 'Polygon',
        'chainSymbol': 'POL',
        'evmChainId': 137,
        'symbol': 'USDC',
        'name': 'USD Coin',
        'decimals': 6,
        'contractAddress': '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
      });

      expect(asset.canonicalTokenId, 'usdc');
    });
  });
}
