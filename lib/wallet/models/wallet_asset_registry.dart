import 'wallet_asset.dart';
import 'wallet_chain.dart';

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

  static const arbitrumAssets = [
    WalletAsset(
      chain: WalletChain.arbitrum,
      symbol: 'ETH',
      name: 'Ethereum',
      decimals: 18,
    ),
    WalletAsset(
      chain: WalletChain.arbitrum,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9',
    ),
    WalletAsset(
      chain: WalletChain.arbitrum,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
    ),
    WalletAsset(
      chain: WalletChain.arbitrum,
      symbol: 'ARB',
      name: 'Arbitrum',
      decimals: 18,
      contractAddress: '0x912CE59144191C1204E64559FE8253a0e49E6548',
    ),
    WalletAsset(
      chain: WalletChain.arbitrum,
      symbol: 'WBTC',
      name: 'Wrapped BTC',
      decimals: 8,
      contractAddress: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f',
    ),
  ];

  static const baseAssets = [
    WalletAsset(
      chain: WalletChain.base,
      symbol: 'ETH',
      name: 'Ethereum',
      decimals: 18,
    ),
    WalletAsset(
      chain: WalletChain.base,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
    ),
    WalletAsset(
      chain: WalletChain.base,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: '0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2',
    ),
    WalletAsset(
      chain: WalletChain.base,
      symbol: 'WETH',
      name: 'Wrapped Ether',
      decimals: 18,
      contractAddress: '0x4200000000000000000000000000000000000006',
      canonicalTokenId: 'eth',
    ),
    WalletAsset(
      chain: WalletChain.base,
      symbol: 'cbBTC',
      name: 'Coinbase Wrapped BTC',
      decimals: 8,
      contractAddress: '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf',
      canonicalTokenId: 'btc',
    ),
  ];

  static const polygonAssets = [
    WalletAsset(
      chain: WalletChain.polygon,
      symbol: 'POL',
      name: 'Polygon Ecosystem Token',
      decimals: 18,
      canonicalTokenId: 'pol',
    ),
    WalletAsset(
      chain: WalletChain.polygon,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
      canonicalTokenId: 'usdc',
    ),
    WalletAsset(
      chain: WalletChain.polygon,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      canonicalTokenId: 'usdt',
    ),
    WalletAsset(
      chain: WalletChain.polygon,
      symbol: 'WETH',
      name: 'Wrapped Ether',
      decimals: 18,
      contractAddress: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
      canonicalTokenId: 'eth',
    ),
    WalletAsset(
      chain: WalletChain.polygon,
      symbol: 'WBTC',
      name: 'Wrapped BTC',
      decimals: 8,
      contractAddress: '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6',
      canonicalTokenId: 'btc',
    ),
  ];

  static const avalancheAssets = [
    WalletAsset(
      chain: WalletChain.avalanche,
      symbol: 'AVAX',
      name: 'Avalanche',
      decimals: 18,
      canonicalTokenId: 'avax',
    ),
    WalletAsset(
      chain: WalletChain.avalanche,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
      canonicalTokenId: 'usdc',
    ),
    WalletAsset(
      chain: WalletChain.avalanche,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7',
      canonicalTokenId: 'usdt',
    ),
    WalletAsset(
      chain: WalletChain.avalanche,
      symbol: 'BTC.b',
      name: 'Bitcoin',
      decimals: 8,
      contractAddress: '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
      canonicalTokenId: 'btc',
    ),
    WalletAsset(
      chain: WalletChain.avalanche,
      symbol: 'WETH.e',
      name: 'Wrapped Ether',
      decimals: 18,
      contractAddress: '0x49D5c2BdFfAC6CE2BFdB6640F4F80f226bc10bAB',
      canonicalTokenId: 'eth',
    ),
    WalletAsset(
      chain: WalletChain.avalanche,
      symbol: 'DAI.e',
      name: 'Dai Stablecoin',
      decimals: 18,
      contractAddress: '0xd586E7F844cEa2F87f50152665BCbc2C279D8d70',
      canonicalTokenId: 'dai',
    ),
  ];

  static const solanaAssets = [
    WalletAsset(
      chain: WalletChain.solana,
      symbol: 'SOL',
      name: 'Solana',
      decimals: 9,
    ),
    WalletAsset(
      chain: WalletChain.solana,
      symbol: 'USDT',
      name: 'Tether USD',
      decimals: 6,
      contractAddress: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
    ),
    WalletAsset(
      chain: WalletChain.solana,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
    ),
  ];

  static const bitcoinAssets = [
    WalletAsset(
      chain: WalletChain.bitcoin,
      symbol: 'BTC',
      name: 'Bitcoin',
      decimals: 8,
      canonicalTokenId: 'btc',
    ),
  ];

  static const suiAssets = [
    WalletAsset(
      chain: WalletChain.sui,
      symbol: 'SUI',
      name: 'Sui',
      decimals: 9,
      canonicalTokenId: 'sui',
    ),
    WalletAsset(
      chain: WalletChain.sui,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress:
          '0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC',
      canonicalTokenId: 'usdc',
    ),
  ];

  static const aptosAssets = [
    WalletAsset(
      chain: WalletChain.aptos,
      symbol: 'APT',
      name: 'Aptos',
      decimals: 8,
      canonicalTokenId: 'apt',
    ),
    WalletAsset(
      chain: WalletChain.aptos,
      symbol: 'USDC',
      name: 'USD Coin',
      decimals: 6,
      contractAddress:
          '0xbae207659db88bea0cbead6da0ed00aac12edcdda169e591cd41c94180b46f3b',
      canonicalTokenId: 'usdc',
    ),
  ];

  static const all = [
    ...bscAssets,
    ...ethereumAssets,
    ...tronAssets,
    ...xLayerAssets,
    ...arbitrumAssets,
    ...baseAssets,
    ...polygonAssets,
    ...avalancheAssets,
    ...bitcoinAssets,
    ...solanaAssets,
    ...suiAssets,
    ...aptosAssets,
  ];

  /// 内置链与默认资产的集中映射。
  ///
  /// 资产数据本身仍是静态配置，但调用方不需要再维护一份链类型分支；
  /// 新增内置链时只需在这里注册对应资产集合。
  static const Map<WalletChain, List<WalletAsset>> _assetsByChain = {
    WalletChain.bsc: bscAssets,
    WalletChain.ethereum: ethereumAssets,
    WalletChain.tron: tronAssets,
    WalletChain.xLayer: xLayerAssets,
    WalletChain.arbitrum: arbitrumAssets,
    WalletChain.base: baseAssets,
    WalletChain.polygon: polygonAssets,
    WalletChain.avalanche: avalancheAssets,
    WalletChain.bitcoin: bitcoinAssets,
    WalletChain.solana: solanaAssets,
    WalletChain.sui: suiAssets,
    WalletChain.aptos: aptosAssets,
  };

  static List<WalletAsset> assetsForChain(WalletChain chain) {
    return _assetsByChain[chain] ?? const <WalletAsset>[];
  }

  static List<WalletAsset> assetsForChainConfig(WalletChainConfig chain) {
    final builtinChain = chain.builtinChain;
    if (builtinChain != null) {
      return assetsForChain(builtinChain);
    }
    return [
      WalletAsset.config(
        chainConfig: chain,
        symbol: chain.symbol,
        name: chain.name,
        decimals: 18,
      ),
    ];
  }

  static List<WalletAsset> mergeCustomAssets(
    WalletChain chain,
    List<WalletAsset> customAssets,
  ) {
    final assets = [...assetsForChain(chain)];
    final existingKeys = assets.map(_assetContractKey).toSet();
    for (final asset in customAssets.where((asset) => asset.chain == chain)) {
      if (existingKeys.add(_assetContractKey(asset))) {
        assets.add(asset);
      }
    }
    return assets;
  }

  static List<WalletAsset> mergeCustomAssetsForChainConfig(
    WalletChainConfig chain,
    List<WalletAsset> customAssets,
  ) {
    final assets = [...assetsForChainConfig(chain)];
    final existingKeys = assets.map(_assetContractKey).toSet();
    for (final asset in customAssets.where(
      (asset) => asset.chainId == chain.id,
    )) {
      if (existingKeys.add(_assetContractKey(asset))) {
        assets.add(asset);
      }
    }
    return assets;
  }

  static String _assetContractKey(WalletAsset asset) {
    return '${asset.chainId}:${_contractKey(asset.chainRef, asset.contractAddress)}';
  }

  static String _contractKey(WalletChainRef chain, String? contractAddress) {
    final value = contractAddress?.trim() ?? '';
    if (value.isEmpty) {
      return 'native';
    }
    return chain.isEvm ? value.toLowerCase() : value;
  }
}
