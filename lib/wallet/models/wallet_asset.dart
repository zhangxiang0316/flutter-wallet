import 'wallet_asset_identity_policy.dart';
import 'wallet_chain.dart';

part 'wallet_asset_serialization.dart';

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
    return _WalletAssetSerialization.toJson(this);
  }

  factory WalletAsset.fromJson(Map<String, dynamic> json) {
    return _WalletAssetSerialization.fromJson(json);
  }
}
