part of 'wallet_custom_asset_service.dart';

List<WalletAsset> _popularAssetsForChain(WalletChainConfig chain) {
  return switch (chain.id) {
    'ethereum' => _ethereumPopularAssets(chain),
    'bsc' => _bscPopularAssets(chain),
    'arbitrum' => _arbitrumPopularAssets(chain),
    'tron' => _tronPopularAssets(chain),
    'solana' => _solanaPopularAssets(chain),
    _ => const <WalletAsset>[],
  };
}

List<WalletAsset> _ethereumPopularAssets(WalletChainConfig chain) {
  return [
    _popularEvmAsset(
      chain,
      folder: 'ethereum',
      symbol: 'WETH',
      name: 'Wrapped Ether',
      decimals: 18,
      contractAddress: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    ),
    _popularEvmAsset(
      chain,
      folder: 'ethereum',
      symbol: 'LINK',
      name: 'Chainlink',
      decimals: 18,
      contractAddress: '0x514910771AF9Ca656af840dff83E8264EcF986CA',
    ),
    _popularEvmAsset(
      chain,
      folder: 'ethereum',
      symbol: 'UNI',
      name: 'Uniswap',
      decimals: 18,
      contractAddress: '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
    ),
    _popularEvmAsset(
      chain,
      folder: 'ethereum',
      symbol: 'AAVE',
      name: 'Aave',
      decimals: 18,
      contractAddress: '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9',
    ),
  ];
}

List<WalletAsset> _bscPopularAssets(WalletChainConfig chain) {
  return [
    _popularEvmAsset(
      chain,
      folder: 'smartchain',
      symbol: 'CAKE',
      name: 'PancakeSwap',
      decimals: 18,
      contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
    ),
  ];
}

List<WalletAsset> _arbitrumPopularAssets(WalletChainConfig chain) {
  return [
    _popularEvmAsset(
      chain,
      folder: 'arbitrum',
      symbol: 'DAI',
      name: 'Dai Stablecoin',
      decimals: 18,
      contractAddress: '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
    ),
    _popularEvmAsset(
      chain,
      folder: 'arbitrum',
      symbol: 'LINK',
      name: 'Chainlink',
      decimals: 18,
      contractAddress: '0xf97f4df75117a78c1A5a0DBb814Af92458539FB4',
    ),
    _popularEvmAsset(
      chain,
      folder: 'arbitrum',
      symbol: 'GMX',
      name: 'GMX',
      decimals: 18,
      contractAddress: '0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a',
    ),
  ];
}

List<WalletAsset> _solanaPopularAssets(WalletChainConfig chain) {
  return [
    WalletAsset.config(
      chainConfig: chain,
      symbol: 'JUP',
      name: 'Jupiter',
      decimals: 6,
      contractAddress: 'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN',
      logoUrl:
          'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/assets/JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN/logo.png',
      isCustom: true,
    ),
  ];
}

List<WalletAsset> _tronPopularAssets(WalletChainConfig chain) {
  return [
    _popularTronAsset(
      chain,
      symbol: 'JST',
      name: 'JUST',
      decimals: 18,
      contractAddress: 'TCFLL5dx5ZJdKnWuesXxi1VPwjLVmWZZy9',
    ),
    _popularTronAsset(
      chain,
      symbol: 'WIN',
      name: 'WINkLink',
      decimals: 6,
      contractAddress: 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7',
    ),
    _popularTronAsset(
      chain,
      symbol: 'USDD',
      name: 'Decentralized USD',
      decimals: 18,
      contractAddress: 'TPYmHEhy5n8TCEfYGqW2rPxsghSfzghPDn',
    ),
  ];
}

WalletAsset _popularEvmAsset(
  WalletChainConfig chain, {
  required String folder,
  required String symbol,
  required String name,
  required int decimals,
  required String contractAddress,
}) {
  return WalletAsset.config(
    chainConfig: chain,
    symbol: symbol,
    name: name,
    decimals: decimals,
    contractAddress: contractAddress,
    logoUrl: _trustWalletLogo(folder, contractAddress),
    isCustom: true,
  );
}

WalletAsset _popularTronAsset(
  WalletChainConfig chain, {
  required String symbol,
  required String name,
  required int decimals,
  required String contractAddress,
}) {
  return WalletAsset.config(
    chainConfig: chain,
    symbol: symbol,
    name: name,
    decimals: decimals,
    contractAddress: contractAddress,
    logoUrl:
        'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/tron/assets/$contractAddress/logo.png',
    isCustom: true,
  );
}
