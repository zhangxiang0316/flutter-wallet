import 'wallet_chain.dart';

/// 首页常用代币身份及其展示元数据。
///
/// 用户添加自定义资产时也可以保存列表之外的动态身份；未选择的资产保持独立
/// 展示，避免仅凭 symbol 把同名仿冒代币合并进主资产。
class WalletCanonicalToken {
  const WalletCanonicalToken({
    required this.id,
    required this.symbol,
    required this.name,
  });

  final String id;
  final String symbol;
  final String name;

  static const values = [
    WalletCanonicalToken(id: 'usdt', symbol: 'USDT', name: 'Tether USD'),
    WalletCanonicalToken(id: 'usdc', symbol: 'USDC', name: 'USD Coin'),
    WalletCanonicalToken(id: 'eth', symbol: 'ETH', name: 'Ethereum'),
    WalletCanonicalToken(id: 'btc', symbol: 'BTC', name: 'Bitcoin'),
    WalletCanonicalToken(id: 'bnb', symbol: 'BNB', name: 'BNB'),
    WalletCanonicalToken(id: 'sol', symbol: 'SOL', name: 'Solana'),
    WalletCanonicalToken(id: 'sui', symbol: 'SUI', name: 'Sui'),
    WalletCanonicalToken(id: 'apt', symbol: 'APT', name: 'Aptos'),
    WalletCanonicalToken(id: 'trx', symbol: 'TRX', name: 'TRON'),
  ];

  static WalletCanonicalToken? fromId(String? value) {
    final normalized = normalizeId(value);
    if (normalized == null) return null;
    for (final token in values) {
      if (token.id == normalized) return token;
    }
    return null;
  }

  /// 标准化用户明确选择的首页归类 ID。
  ///
  /// ID 不限定在内置常用代币中，因此未来新增 DAI 等币种也无需修改代码。
  static String? normalizeId(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty ||
        !RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}

class WalletAsset {
  const WalletAsset({
    required this.chain,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.contractAddress,
    this.logoUrl,
    this.canonicalTokenId,
    this.isCustom = false,
  }) : chainConfig = null;

  const WalletAsset.config({
    required WalletChainConfig this.chainConfig,
    required this.symbol,
    required this.name,
    required this.decimals,
    this.contractAddress,
    this.logoUrl,
    this.canonicalTokenId,
    this.isCustom = false,
  }) : chain = null;

  final WalletChain? chain;
  final WalletChainConfig? chainConfig;
  final String symbol;
  final String name;
  final int decimals;
  final String? contractAddress;
  final String? logoUrl;
  final String? canonicalTokenId;
  final bool isCustom;

  WalletChainRef get chainRef => chainConfig ?? chain!;
  String get chainId => chainRef.id;

  bool get isNative => contractAddress == null || contractAddress!.isEmpty;

  String get assetKey {
    return [chainId, contractAddress ?? 'native', symbol].join(':');
  }

  Map<String, dynamic> toJson() {
    return {
      'chainId': chainId,
      'chainName': chainRef.name,
      'chainSymbol': chainRef.symbol,
      'evmChainId': chainRef.evmChainId,
      'symbol': symbol,
      'name': name,
      'decimals': decimals,
      'contractAddress': contractAddress,
      'logoUrl': logoUrl,
      'canonicalTokenId': canonicalTokenId,
      'isCustom': isCustom,
    };
  }

  factory WalletAsset.fromJson(Map<String, dynamic> json) {
    final chainId = json['chainId']?.toString() ?? WalletChain.bsc.id;
    final chain = WalletChain.values.cast<WalletChain?>().firstWhere(
      (item) => item?.id == chainId,
      orElse: () => null,
    );
    final decimalsValue = json['decimals'];
    final symbol = json['symbol'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final decimals = decimalsValue is int
        ? decimalsValue
        : int.tryParse(decimalsValue?.toString() ?? '') ?? 0;
    final contractAddress = json['contractAddress'] as String?;
    final logoUrl = json['logoUrl']?.toString().trim();
    final evmChainId = int.tryParse(json['evmChainId']?.toString() ?? '');
    final canonicalTokenId =
        WalletCanonicalToken.normalizeId(
          json['canonicalTokenId']?.toString(),
        ) ??
        _legacyCanonicalTokenId(
          evmChainId: evmChainId,
          contractAddress: contractAddress,
        );
    final isCustom = json['isCustom'] as bool? ?? true;
    if (chain != null) {
      return WalletAsset(
        chain: chain,
        symbol: symbol,
        name: name,
        decimals: decimals,
        contractAddress: contractAddress,
        logoUrl: logoUrl?.isEmpty == true ? null : logoUrl,
        canonicalTokenId: canonicalTokenId,
        isCustom: isCustom,
      );
    }
    return WalletAsset.config(
      chainConfig: WalletChainConfig.customEvm(
        id: chainId,
        name: json['chainName']?.toString() ?? chainId,
        symbol: json['chainSymbol']?.toString() ?? '',
        rpcUrls: const ['http://localhost'],
        evmChainId: evmChainId ?? 1,
      ),
      symbol: symbol,
      name: name,
      decimals: decimals,
      contractAddress: contractAddress,
      logoUrl: logoUrl?.isEmpty == true ? null : logoUrl,
      canonicalTokenId: canonicalTokenId,
      isCustom: isCustom,
    );
  }
}

/// 迁移旧版本已经添加、但尚未保存标准身份的官方资产。
String? _legacyCanonicalTokenId({
  required int? evmChainId,
  required String? contractAddress,
}) {
  final contract = contractAddress?.trim().toLowerCase() ?? '';
  if (evmChainId == 137 &&
      contract == '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359') {
    return 'usdc';
  }
  return null;
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
    ...bitcoinAssets,
    ...solanaAssets,
    ...suiAssets,
    ...aptosAssets,
  ];

  static List<WalletAsset> assetsForChain(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return bscAssets;
      case WalletChain.ethereum:
        return ethereumAssets;
      case WalletChain.tron:
        return tronAssets;
      case WalletChain.xLayer:
        return xLayerAssets;
      case WalletChain.arbitrum:
        return arbitrumAssets;
      case WalletChain.bitcoin:
        return bitcoinAssets;
      case WalletChain.solana:
        return solanaAssets;
      case WalletChain.sui:
        return suiAssets;
      case WalletChain.aptos:
        return aptosAssets;
    }
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

  static WalletAsset? findTronAsset(String contractAddress) {
    return findAssetByContract(WalletChain.tron, contractAddress);
  }

  static WalletAsset? findAssetByContract(
    WalletChain chain,
    String contractAddress, {
    List<WalletAsset> customAssets = const [],
  }) {
    final normalized = _contractKey(chain, contractAddress);
    final assets = mergeCustomAssets(chain, customAssets);
    for (final asset in assets) {
      if (_contractKey(chain, asset.contractAddress) == normalized) {
        return asset;
      }
    }
    return null;
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
