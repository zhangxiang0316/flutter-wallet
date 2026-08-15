part of '../chain_balance_service.dart';

extension _BitcoinChainBalance on ChainBalanceService {
  /// 通过 Esplora 兼容接口查询 Bitcoin 地址的已确认和内存池余额。
  Future<List<ChainBalance>> _loadBitcoinBalances({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final data = await RpcRetryHelper.execute<Map<dynamic, dynamic>>(
      rpcUrls: _bitcoinApiUrls(chain),
      chainName: chain.name,
      operation: 'address balance request',
      logName: 'ChainBalanceService',
      request: (apiUrl) async {
        final response = await _dio.get('$apiUrl/address/$address');
        final responseData = response.data;
        if (responseData is Map) return responseData;
        throw StateError('Invalid Bitcoin balance response');
      },
      validator: (responseData) =>
          responseData['chain_stats'] is Map &&
          responseData['mempool_stats'] is Map,
    );
    final chainStats = data['chain_stats'] as Map;
    final mempoolStats = data['mempool_stats'] as Map;
    final confirmed =
        _bitcoinSats(chainStats['funded_txo_sum']) -
        _bitcoinSats(chainStats['spent_txo_sum']);
    final pending =
        _bitcoinSats(mempoolStats['funded_txo_sum']) -
        _bitcoinSats(mempoolStats['spent_txo_sum']);
    final totalSats = confirmed + pending;
    final asset = WalletAssetRegistry.bitcoinAssets.single;
    return [
      ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(totalSats, asset.decimals),
        address: address,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: asset.decimals,
      ),
    ];
  }

  List<String> _bitcoinApiUrls(WalletChainConfig chain) {
    return RpcRetryHelper.mergeRpcUrls(
      chain.rpcUrls,
      ChainBalanceService._bitcoinApiFallbacks,
    );
  }

  BigInt _bitcoinSats(Object? value) {
    return BigInt.tryParse(value?.toString() ?? '') ?? BigInt.zero;
  }
}
