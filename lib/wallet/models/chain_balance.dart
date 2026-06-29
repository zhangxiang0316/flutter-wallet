import 'wallet_chain.dart';

class ChainBalance {
  const ChainBalance({
    required this.chain,
    required this.symbol,
    required this.name,
    required this.amount,
    required this.address,
    this.contractAddress,
    this.logoUrl,
    this.decimals = 0,
    this.error,
  }) : chainConfig = null;

  const ChainBalance.config({
    required WalletChainConfig this.chainConfig,
    required this.symbol,
    required this.name,
    required this.amount,
    required this.address,
    this.contractAddress,
    this.logoUrl,
    this.decimals = 0,
    this.error,
  }) : chain = null;

  final WalletChain? chain;
  final WalletChainConfig? chainConfig;
  final String symbol;
  final String name;
  final String amount;
  final String address;
  final String? contractAddress;
  final String? logoUrl;
  final int decimals;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
  bool get isNative => contractAddress == null || contractAddress!.isEmpty;
  WalletChainRef get chainRef => chainConfig ?? chain!;
  String get chainId => chainRef.id;

  @override
  String toString() {
    return 'ChainBalance(chain: $chainId, symbol: $symbol, '
        'amount: $amount, decimals: $decimals, address: $address, '
        'contractAddress: ${contractAddress ?? '-'}, error: ${error ?? '-'})';
  }
}
