part of '../chain_balance_service.dart';

extension _EvmChainBalance on ChainBalanceService {
  Future<List<ChainBalance>> _loadEvmBalances({
    required WalletChainConfig chain,
    required List<WalletAsset> assets,
    required String address,
  }) async {
    return Future.wait(
      assets.map(
        (asset) => _loadEvmAsset(chain: chain, asset: asset, address: address),
      ),
    );
  }

  /// 根据资产类型分发到原生币或 ERC20 查询逻辑。
  Future<ChainBalance> _loadEvmAsset({
    required WalletChainConfig chain,
    required WalletAsset asset,
    required String address,
  }) async {
    if (asset.isNative) {
      return _loadEvmNativeBalance(
        chain: chain,
        asset: asset,
        address: address,
      );
    }
    return _loadEvmTokenBalance(chain: chain, asset: asset, address: address);
  }

  /// 查询 EVM 原生币余额。
  ///
  /// 使用 `eth_getBalance` 获取最小单位数量（wei），再按资产 decimals 格式化。
  Future<ChainBalance> _loadEvmNativeBalance({
    required WalletChainConfig chain,
    required WalletAsset asset,
    required String address,
  }) async {
    try {
      final data = await _postEvmRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
          'id': 1,
        },
      );
      final wei = _parseHexQuantity(data['result'] as String);
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(wei, asset.decimals),
        address: address,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询 EVM ERC20 代币余额。
  ///
  /// 使用 `eth_call` 调用 ERC20 `balanceOf(address)`，不需要发交易或消耗 gas。
  Future<ChainBalance> _loadEvmTokenBalance({
    required WalletChainConfig chain,
    required WalletAsset asset,
    required String address,
  }) async {
    try {
      final data = await _postEvmRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [
            {
              'to': asset.contractAddress,
              'data': ChainBalanceService.erc20BalanceOfData(address),
            },
            'latest',
          ],
          'id': 1,
        },
      );
      final value = _parseHexQuantity(data['result'] as String);
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(value, asset.decimals),
        address: address,
        contractAddress: asset.contractAddress,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        contractAddress: asset.contractAddress,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询 TRON 链余额。
  ///
  /// TRX 原生余额和 TRC20 余额走不同接口。返回时会保证已知代币都在列表中：
  /// 没查到的已知代币补 0，接口返回但资产表未知的 TRC20 也保留展示。
}
