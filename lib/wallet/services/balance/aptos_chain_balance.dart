part of '../chain_balance_service.dart';

extension _AptosChainBalance on ChainBalanceService {
  Future<List<ChainBalance>> _loadAptosBalances({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final normalized = WalletTransferService.normalizeAptosAddress(address);
    final assets = WalletAssetRegistry.assetsForChainConfig(chain);
    return Future.wait(
      assets.map((asset) async {
        try {
          final assetId = asset.isNative
              ? '0x1::aptos_coin::AptosCoin'
              : asset.contractAddress!;
          final response = await _dio.get(
            '${chain.rpcUrl}/accounts/$normalized/balance/'
            '${Uri.encodeComponent(assetId)}',
          );
          final raw = BigInt.parse(response.data.toString());
          return ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: _formatUnits(raw, asset.decimals),
            address: normalized,
            contractAddress: asset.contractAddress,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
          );
        } catch (error) {
          return ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: normalized,
            contractAddress: asset.contractAddress,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
            error: error.toString(),
          );
        }
      }),
    );
  }
}
