part of '../chain_balance_service.dart';

extension _SuiChainBalance on ChainBalanceService {
  /// 使用 Sui gRPC v2 查询 SUI 和内置 Coin 资产余额。
  Future<List<ChainBalance>> _loadSuiBalances({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final normalizedAddress = address.trim().toLowerCase();
    if (!SuiAccount.isValidAddress(normalizedAddress)) {
      throw const FormatException('Invalid Sui address');
    }

    final client = SuiGrpcClient(
      network: SuiNetwork.mainnet,
      dio: _dio,
      endpoint: chain.rpcUrl,
    );
    final assets = WalletAssetRegistry.assetsForChainConfig(chain);
    return Future.wait(
      assets.map((asset) async {
        try {
          final coinType = asset.isNative
              ? '0x2::sui::SUI'
              : asset.contractAddress!;
          final balance = await client.balanceOf(
            normalizedAddress,
            coinType: coinType,
          );
          return ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: _formatUnits(balance.totalBalance, asset.decimals),
            address: normalizedAddress,
            contractAddress: asset.contractAddress,
            logoUrl: asset.logoUrl,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
          );
        } catch (error) {
          return ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: normalizedAddress,
            contractAddress: asset.contractAddress,
            logoUrl: asset.logoUrl,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
            error: error.toString(),
          );
        }
      }),
    );
  }
}
