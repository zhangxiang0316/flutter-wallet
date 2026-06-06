import 'wallet_chain.dart';

class WalletAsset {
  const WalletAsset({
    required this.chain,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.contractAddress,
  });

  final WalletChain chain;
  final String symbol;
  final String name;
  final int decimals;
  final String? contractAddress;

  bool get isNative => contractAddress == null || contractAddress!.isEmpty;
}

class WalletAssetRegistry {
  static const bscAssets = [
    WalletAsset(
      chain: WalletChain.bsc,
      symbol: 'BNB',
      name: 'BNB',
      decimals: 18,
    ),
    WalletAsset(
      chain: WalletChain.bsc,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 18,
      contractAddress: '0x55d398326f99059fF775485246999027B3197955',
    ),
    WalletAsset(
      chain: WalletChain.bsc,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 18,
      contractAddress: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    ),
    WalletAsset(
      chain: WalletChain.bsc,
      symbol: 'BUSD',
      name: 'Binance-Peg BUSD',
      decimals: 18,
      contractAddress: '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
    ),
    WalletAsset(
      chain: WalletChain.bsc,
      symbol: 'ETH',
      name: 'Binance-Peg Ethereum',
      decimals: 18,
      contractAddress: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
    ),
    WalletAsset(
      chain: WalletChain.bsc,
      symbol: 'BTCB',
      name: 'Binance-Peg BTCB',
      decimals: 18,
      contractAddress: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
    ),
  ];

  static const tronAssets = [
    WalletAsset(
      chain: WalletChain.tron,
      symbol: 'TRX',
      name: 'TRON',
      decimals: 6,
    ),
    WalletAsset(
      chain: WalletChain.tron,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    ),
    WalletAsset(
      chain: WalletChain.tron,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: 'TEkxiTehnzSmSe2XqrBj4w32RUN966rdz8',
    ),
    WalletAsset(
      chain: WalletChain.tron,
      symbol: 'TUSD',
      name: 'TrueUSD',
      decimals: 18,
      contractAddress: 'TUpMhErZL2fhh4sVNULAbNKLokS4GjC1F4',
    ),
  ];

  static const ethereumAssets = [
    WalletAsset(
      chain: WalletChain.ethereum,
      symbol: 'ETH',
      name: 'Ethereum',
      decimals: 18,
    ),
    WalletAsset(
      chain: WalletChain.ethereum,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    ),
    WalletAsset(
      chain: WalletChain.ethereum,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    ),
    WalletAsset(
      chain: WalletChain.ethereum,
      symbol: 'DAI',
      name: 'Dai Stablecoin',
      decimals: 18,
      contractAddress: '0x6B175474E89094C44Da98b954EedeAC495271d0F',
    ),
    WalletAsset(
      chain: WalletChain.ethereum,
      symbol: 'WBTC',
      name: 'Wrapped BTC',
      decimals: 8,
      contractAddress: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
    ),
  ];

  static const xLayerAssets = [
    WalletAsset(
      chain: WalletChain.xLayer,
      symbol: 'OKB',
      name: 'OKB',
      decimals: 18,
    ),
    WalletAsset(
      chain: WalletChain.xLayer,
      symbol: 'USDT',
      name: 'Tether USD0',
      decimals: 6,
      contractAddress: '0x779Ded0c9e1022225f8E0630b35a9b54bE713736',
    ),
    WalletAsset(
      chain: WalletChain.xLayer,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: '0x74b7F16337b8972027F6196A17a631aC6dE26d22',
    ),
  ];

  static const all = [
    ...bscAssets,
    ...ethereumAssets,
    ...tronAssets,
    ...xLayerAssets,
  ];

  static WalletAsset? findTronAsset(String contractAddress) {
    final normalized = contractAddress.trim();
    for (final asset in tronAssets) {
      if (asset.contractAddress == normalized) {
        return asset;
      }
    }
    return null;
  }
}
