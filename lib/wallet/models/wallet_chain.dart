enum WalletChain {
  bsc(
    id: 'bsc',
    name: 'BNB Smart Chain',
    symbol: 'BNB',
    rpcUrl: 'https://bsc-dataseed.bnbchain.org',
    evmChainId: 56,
  ),
  ethereum(
    id: 'ethereum',
    name: 'Ethereum',
    symbol: 'ETH',
    rpcUrl: 'https://ethereum-rpc.publicnode.com',
    evmChainId: 1,
  ),
  xLayer(
    id: 'x-layer',
    name: 'X Layer',
    symbol: 'OKB',
    rpcUrl: 'https://rpc.xlayer.tech',
    evmChainId: 196,
  ),
  arbitrum(
    id: 'arbitrum',
    name: 'Arbitrum',
    symbol: 'ETH',
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    evmChainId: 42161,
  ),
  solana(
    id: 'solana',
    name: 'Solana',
    symbol: 'SOL',
    rpcUrl: 'https://api.mainnet-beta.solana.com',
  ),
  tron(
    id: 'tron',
    name: 'TRON',
    symbol: 'TRX',
    rpcUrl: 'https://api.trongrid.io',
  );

  const WalletChain({
    required this.id,
    required this.name,
    required this.symbol,
    required this.rpcUrl,
    this.evmChainId,
  });

  final String id;
  final String name;
  final String symbol;
  final String rpcUrl;
  final int? evmChainId;

  bool get isEvm => evmChainId != null;
}
