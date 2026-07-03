part of '../chain_balance_service.dart';

extension _TronChainBalance on ChainBalanceService {
  Future<List<ChainBalance>> _loadTronBalances({
    required WalletChainConfig chain,
    required String address,
    required List<WalletAsset> customAssets,
  }) async {
    final nativeBalance = await _loadTronNativeBalance(
      chain: chain,
      address: address,
    );
    final tokenBalances = await _loadTronTokenBalances(
      chain: chain,
      address: address,
      customAssets: customAssets,
    );
    final tokenMap = {
      for (final balance in tokenBalances)
        if (balance.contractAddress != null) balance.contractAddress!: balance,
    };
    final configuredAssets =
        WalletAssetRegistry.mergeCustomAssetsForChainConfig(
          chain,
          customAssets,
        );
    final knownTokens = configuredAssets.where((asset) => !asset.isNative).map((
      asset,
    ) {
      return tokenMap[asset.contractAddress] ??
          ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: address,
            contractAddress: asset.contractAddress,
            logoUrl: asset.logoUrl,
            decimals: asset.decimals,
          );
    });
    final knownContracts = configuredAssets
        .where((asset) => !asset.isNative)
        .map((asset) => asset.contractAddress)
        .whereType<String>()
        .toSet();
    final unknownTokens = tokenBalances.where((balance) {
      final contractAddress = balance.contractAddress;
      return contractAddress != null &&
          !knownContracts.contains(contractAddress);
    });
    return [nativeBalance, ...knownTokens, ...unknownTokens];
  }

  /// 查询 Solana 链余额。
  ///
  /// 空地址直接返回 0 余额兜底。正常情况下会并发查询 SOL 原生余额和当前配置的
  /// SPL Token 余额。
  Future<ChainBalance> _loadTronNativeBalance({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final asset = WalletAssetRegistry.tronAssets.first;
    try {
      final data = await _postTronAccount(chain, address);
      final balance = data['balance'];
      final sun = balance is int
          ? BigInt.from(balance)
          : BigInt.tryParse(balance?.toString() ?? '0') ?? BigInt.zero;
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(sun, asset.decimals),
        address: address,
        logoUrl: asset.logoUrl,
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
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  /// 查询 TRON TRC20 余额列表。
  ///
  /// TRONGrid 账号接口会返回账号持有的 TRC20 合约和原始余额。已知合约会映射成
  /// 资产名称和 decimals；未知合约保留为 `TRC20`，方便后续用户添加自定义资产。
  Future<List<ChainBalance>> _loadTronTokenBalances({
    required WalletChainConfig chain,
    required String address,
    required List<WalletAsset> customAssets,
  }) async {
    Object? lastError;
    try {
      final data = await RpcRetryHelper.execute<Map<dynamic, dynamic>>(
        rpcUrls: _tronRpcUrls(chain),
        chainName: 'TRON',
        operation: 'token request',
        logName: 'ChainBalanceService',
        request: (rpcUrl) async {
          final response = await _dio.get(
            '$rpcUrl/v1/accounts/$address',
            options: Options(headers: {'content-type': 'application/json'}),
          );
          final data = response.data;
          if (data is Map) {
            return data;
          }
          throw StateError('Invalid TRON token response');
        },
        validator: (_) => true,
      );
      if (data['data'] is! List || (data['data'] as List).isEmpty) {
        return [];
      }
      final account = (data['data'] as List).first;
      if (account is! Map || account['trc20'] is! List) {
        return [];
      }
      final configuredAssets =
          WalletAssetRegistry.mergeCustomAssetsForChainConfig(
            chain,
            customAssets,
          );
      final assetsByContract = {
        for (final asset in configuredAssets)
          if (asset.contractAddress != null) asset.contractAddress!: asset,
      };
      final balances = <ChainBalance>[];
      for (final item in account['trc20'] as List) {
        if (item is! Map || item.isEmpty) continue;
        final contractAddress = item.keys.first.toString();
        final rawValue = item.values.first.toString();
        final asset = assetsByContract[contractAddress];
        final decimals = asset?.decimals ?? 6;
        balances.add(
          ChainBalance.config(
            chainConfig: chain,
            symbol: asset?.symbol ?? 'TRC20',
            name: asset?.name ?? contractAddress,
            amount: _formatUnits(
              BigInt.tryParse(rawValue) ?? BigInt.zero,
              decimals,
            ),
            address: address,
            contractAddress: contractAddress,
            logoUrl: asset?.logoUrl,
            decimals: decimals,
          ),
        );
      }
      return balances;
    } catch (error) {
      lastError = error;
    }
    final errorMessage =
        'TRC20 balance lookup failed: ${lastError ?? 'unknown error'}';
    return WalletAssetRegistry.mergeCustomAssetsForChainConfig(
          chain,
          customAssets,
        )
        .where((asset) => !asset.isNative)
        .map(
          (asset) => ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: address,
            contractAddress: asset.contractAddress,
            logoUrl: asset.logoUrl,
            decimals: asset.decimals,
            error: errorMessage,
          ),
        )
        .toList();
  }

  /// 生成 ERC20 `balanceOf(address)` 调用数据。
  ///
  /// `0x70a08231` 是 `balanceOf(address)` 的 4 字节方法选择器，后面拼接 32 字节
  /// 左侧补零的地址参数。
}
