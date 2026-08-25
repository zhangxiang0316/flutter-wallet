part of 'wallet_asset.dart';

/// WalletAsset 的持久化格式及旧版本数据迁移。
abstract final class _WalletAssetSerialization {
  static Map<String, dynamic> toJson(WalletAsset asset) {
    return {
      'chainId': asset.chainId,
      'chainName': asset.chainRef.name,
      'chainSymbol': asset.chainRef.symbol,
      'evmChainId': asset.chainRef.evmChainId,
      'symbol': asset.symbol,
      'name': asset.name,
      'decimals': asset.decimals,
      'contractAddress': asset.contractAddress,
      'logoUrl': asset.logoUrl,
      'canonicalTokenId': asset.canonicalTokenId,
      'isCustom': asset.isCustom,
    };
  }

  static WalletAsset fromJson(Map<String, dynamic> json) {
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

  /// 迁移旧版本已经添加、但尚未保存标准身份的官方资产。
  static String? _legacyCanonicalTokenId({
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
}
