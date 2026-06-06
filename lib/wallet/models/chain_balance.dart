import 'wallet_chain.dart';

class ChainBalance {
  const ChainBalance({
    required this.chain,
    required this.symbol,
    required this.name,
    required this.amount,
    required this.address,
    this.contractAddress,
    this.decimals = 0,
    this.error,
  });

  final WalletChain chain;
  final String symbol;
  final String name;
  final String amount;
  final String address;
  final String? contractAddress;
  final int decimals;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;
  bool get isNative => contractAddress == null || contractAddress!.isEmpty;
}
