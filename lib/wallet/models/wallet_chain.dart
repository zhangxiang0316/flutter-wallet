enum WalletChain {
  bsc(
    id: 'bsc',
    name: 'BNB Smart Chain',
    symbol: 'BNB',
    rpcUrl: 'https://bsc-dataseed.bnbchain.org',
    evmChainId: 56,
  ),
  xLayer(
    id: 'x-layer',
    name: 'X Layer',
    symbol: 'OKB',
    rpcUrl: 'https://rpc.xlayer.tech',
    evmChainId: 196,
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
