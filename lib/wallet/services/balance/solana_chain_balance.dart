part of '../chain_balance_service.dart';

extension _SolanaChainBalance on ChainBalanceService {
  Future<List<ChainBalance>> _loadSolanaBalances({
    required WalletChainConfig chain,
    required String address,
    required List<WalletAsset> customAssets,
  }) async {
    if (address.trim().isEmpty) {
      return _fallbackSolanaBalances(
        chain: chain,
        address: address,
        customAssets: customAssets,
      );
    }

    final solanaAssets = WalletAssetRegistry.mergeCustomAssetsForChainConfig(
      chain,
      customAssets,
    );
    final tokenAssets = solanaAssets
        .where((asset) => !asset.isNative)
        .toList(growable: false);
    final nativeBalanceFuture = _loadSolanaNativeBalance(
      chain: chain,
      address: address,
    );
    final tokenBalancesFuture = _loadSolanaTokenBalances(
      chain: chain,
      address: address,
      assets: tokenAssets,
    );
    final nativeBalance = await nativeBalanceFuture;
    final tokenBalances = await tokenBalancesFuture;
    return [nativeBalance, ...tokenBalances];
  }

  /// 构造 Solana 资产的 0 余额兜底列表。
  ///
  /// 用于 Solana 地址缺失、RPC 超时或整链查询不可用时，保证 UI 仍有稳定结构。
  List<ChainBalance> _fallbackSolanaBalances({
    required WalletChainConfig chain,
    required String address,
    required List<WalletAsset> customAssets,
    String? error,
  }) {
    return WalletAssetRegistry.mergeCustomAssetsForChainConfig(
          chain,
          customAssets,
        )
        .map(
          (asset) => ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: address,
            contractAddress: asset.contractAddress,
            logoUrl: asset.logoUrl,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
            error: error,
          ),
        )
        .toList(growable: false);
  }

  /// 查询 SOL 原生余额。
  ///
  /// Solana 节点返回 lamports，需要按 SOL 的 decimals 转换成人类可读数量。
  Future<ChainBalance> _loadSolanaNativeBalance({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final asset = WalletAssetRegistry.solanaAssets.first;
    try {
      final data = await _postSolanaRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getBalance',
          'params': [address],
        },
      );
      final result = data['result'];
      final value = result is Map ? result['value'] : null;
      final lamports = value is int
          ? BigInt.from(value)
          : BigInt.tryParse(value?.toString() ?? '0') ?? BigInt.zero;
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(lamports, asset.decimals),
        address: address,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: asset.decimals,
      );
    } catch (e) {
      developer.log(
        'Solana native balance failed; using zero fallback: $e',
        name: 'ChainBalanceService',
      );
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

  /// 查询单个 Solana SPL Token 余额。
  ///
  /// 默认优先计算 ATA 并调用 `getTokenAccountBalance` 直查余额。这个接口不需要
  /// 扫描 owner 下的账户，公共节点兼容性比 `getTokenAccountsByOwner` 更好。
  Future<ChainBalance> _loadSolanaTokenBalance(
    WalletChainConfig chain,
    String address,
    WalletAsset asset,
  ) async {
    try {
      return await _loadSolanaAssociatedTokenBalance(chain, address, asset);
    } catch (e) {
      developer.log(
        'Solana ${asset.symbol} ATA balance failed; falling back to owner lookup: $e',
        name: 'ChainBalanceService',
      );
      return _loadSolanaTokenBalanceByOwner(chain, address, asset);
    }
  }

  /// 通过 Solana ATA 地址直接查询 SPL Token 余额。
  ///
  /// ATA 未创建时，链上会返回 account not found，这代表该币种余额为 0，不应当标记
  /// 为查询失败。
  Future<ChainBalance> _loadSolanaAssociatedTokenBalance(
    WalletChainConfig chain,
    String address,
    WalletAsset asset,
  ) async {
    final contractAddress = asset.contractAddress;
    if (contractAddress == null || contractAddress.trim().isEmpty) {
      return _zeroSolanaTokenBalance(chain, address, asset);
    }

    final owner = Ed25519HDPublicKey.fromBase58(address);
    final mint = Ed25519HDPublicKey.fromBase58(contractAddress);
    final tokenAccount = await findAssociatedTokenAddress(
      owner: owner,
      mint: mint,
    );
    final data = await _postSolanaRpc(
      chain: chain,
      data: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getTokenAccountBalance',
        'params': [tokenAccount.toBase58()],
      },
      returnErrorWhen: _isSolanaTokenAccountNotFoundError,
    );
    if (data['error'] != null) {
      return _zeroSolanaTokenBalance(chain, address, asset);
    }

    final result = data['result'];
    final value = result is Map ? result['value'] : null;
    if (value is! Map) {
      throw StateError('Invalid Solana ${asset.symbol} token account balance');
    }
    final rawAmount = BigInt.tryParse(value['amount']?.toString() ?? '');
    if (rawAmount == null) {
      throw StateError('Invalid Solana ${asset.symbol} token amount');
    }
    final decimalsValue = value['decimals'];
    final decimals = decimalsValue is int
        ? decimalsValue
        : int.tryParse(decimalsValue?.toString() ?? '') ?? asset.decimals;
    return ChainBalance.config(
      chainConfig: chain,
      symbol: asset.symbol,
      name: asset.name,
      amount: _formatUnits(rawAmount, decimals),
      address: address,
      contractAddress: asset.contractAddress,
      logoUrl: asset.logoUrl,
      canonicalTokenId: asset.canonicalTokenId,
      decimals: decimals,
    );
  }

  /// 通过 owner + mint 扫描 token account 查询 SPL Token 余额。
  ///
  /// 该路径只作为 ATA 直查失败后的兜底。接口返回的是最小单位字符串，需要按
  /// decimals 格式化。
  Future<ChainBalance> _loadSolanaTokenBalanceByOwner(
    WalletChainConfig chain,
    String address,
    WalletAsset asset,
  ) async {
    try {
      final data = await _postSolanaRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            address,
            {'mint': asset.contractAddress},
            {'encoding': 'jsonParsed'},
          ],
        },
      );
      final result = data['result'];
      final values = result is Map ? result['value'] : null;
      if (values is! List) {
        throw StateError('Invalid Solana ${asset.symbol} token response');
      }

      var rawAmountTotal = BigInt.zero;
      var decimals = asset.decimals;
      for (final item in values) {
        final account = item is Map ? item['account'] : null;
        final accountData = account is Map ? account['data'] : null;
        final parsed = accountData is Map ? accountData['parsed'] : null;
        final info = parsed is Map ? parsed['info'] : null;
        if (info is! Map) continue;

        final mint = info['mint']?.toString();
        if (mint != asset.contractAddress) continue;

        final tokenAmount = info['tokenAmount'];
        final decimalsValue = tokenAmount is Map ? tokenAmount['decimals'] : 0;
        decimals = decimalsValue is int
            ? decimalsValue
            : int.tryParse(decimalsValue?.toString() ?? '') ?? asset.decimals;
        final rawAmount = tokenAmount is Map
            ? tokenAmount['amount']?.toString()
            : null;
        rawAmountTotal += BigInt.tryParse(rawAmount ?? '0') ?? BigInt.zero;
      }
      return ChainBalance.config(
        chainConfig: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(rawAmountTotal, decimals),
        address: address,
        contractAddress: asset.contractAddress,
        logoUrl: asset.logoUrl,
        canonicalTokenId: asset.canonicalTokenId,
        decimals: decimals,
      );
    } catch (e) {
      developer.log(
        'Solana ${asset.symbol} balance failed; using zero fallback: $e',
        name: 'ChainBalanceService',
      );
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

  /// 构造 Solana token 的 0 余额记录。
  ChainBalance _zeroSolanaTokenBalance(
    WalletChainConfig chain,
    String address,
    WalletAsset asset,
  ) {
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
    );
  }

  /// 判断 Solana RPC 错误是否代表 ATA 尚未创建。
  bool _isSolanaTokenAccountNotFoundError(Object? error) {
    final message = error is Map
        ? error['message']?.toString().toLowerCase()
        : error?.toString().toLowerCase();
    return message != null &&
        (message.contains('could not find account') ||
            message.contains('account not found') ||
            (message.contains('invalid param') && message.contains('account')));
  }

  /// 查询 Solana 钱包下所有 SPL Token 余额。
  ///
  /// 默认先按 mint 分别查询 USDT、USDC 等已配置资产，这是 Solana 公共节点最轻量
  /// 且兼容性最好的路径。只有某些 mint 查询失败时，才按 Token Program 拉取当前
  /// owner 的全部 token account 作为兜底，再按 mint 本地汇总。
  Future<List<ChainBalance>> _loadSolanaTokenBalances({
    required WalletChainConfig chain,
    required String address,
    required List<WalletAsset> assets,
  }) async {
    if (assets.isEmpty) {
      return [];
    }

    final perMintBalances = await Future.wait(
      assets.map((asset) => _loadSolanaTokenBalance(chain, address, asset)),
    );
    final failedIndexes = <int>[];
    for (var index = 0; index < perMintBalances.length; index++) {
      if (perMintBalances[index].hasError) {
        failedIndexes.add(index);
      }
    }
    if (failedIndexes.isEmpty) {
      return perMintBalances;
    }

    try {
      final tokenAccounts = await _loadSolanaTokenAccountsByOwner(
        chain: chain,
        address: address,
      );
      final nextBalances = [...perMintBalances];
      for (final index in failedIndexes) {
        final asset = assets[index];
        nextBalances[index] = _buildSolanaTokenBalance(
          chain,
          address,
          asset,
          tokenAccounts,
        );
      }
      return nextBalances;
    } catch (e) {
      developer.log(
        'Solana token account list fallback failed: $e',
        name: 'ChainBalanceService',
      );
      return perMintBalances;
    }
  }

  /// 拉取当前 Solana 地址持有的全部 SPL Token account，并按 mint 汇总。
  Future<Map<String, _SolanaTokenBalance>> _loadSolanaTokenAccountsByOwner({
    required WalletChainConfig chain,
    required String address,
  }) async {
    final data = await _postSolanaRpc(
      chain: chain,
      data: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getTokenAccountsByOwner',
        'params': [
          address,
          {'programId': ChainBalanceService._solanaTokenProgramId},
          {'encoding': 'jsonParsed'},
        ],
      },
    );
    final result = data['result'];
    final values = result is Map ? result['value'] : null;
    if (values is! List) {
      throw StateError('Invalid Solana token accounts response');
    }

    final balances = <String, _SolanaTokenBalance>{};
    for (final item in values) {
      final parsed = _solanaParsedAccountData(item);
      final info = parsed is Map ? parsed['info'] : null;
      if (info is! Map) continue;

      final mint = info['mint']?.toString();
      if (mint == null || mint.isEmpty) continue;

      final tokenAmount = info['tokenAmount'];
      final rawAmount = tokenAmount is Map
          ? BigInt.tryParse(tokenAmount['amount']?.toString() ?? '')
          : null;
      if (rawAmount == null) continue;

      final decimalsValue = tokenAmount is Map ? tokenAmount['decimals'] : null;
      final decimals = decimalsValue is int
          ? decimalsValue
          : int.tryParse(decimalsValue?.toString() ?? '') ?? 0;
      final current = balances[mint];
      balances[mint] = _SolanaTokenBalance(
        rawAmount: (current?.rawAmount ?? BigInt.zero) + rawAmount,
        decimals: current?.decimals ?? decimals,
      );
    }
    return balances;
  }

  /// 根据已汇总的 Solana token account 余额构造单个资产余额。
  ChainBalance _buildSolanaTokenBalance(
    WalletChainConfig chain,
    String address,
    WalletAsset asset,
    Map<String, _SolanaTokenBalance> tokenAccounts,
  ) {
    final tokenBalance = tokenAccounts[asset.contractAddress];
    final decimals = tokenBalance?.decimals ?? asset.decimals;
    return ChainBalance.config(
      chainConfig: chain,
      symbol: asset.symbol,
      name: asset.name,
      amount: _formatUnits(tokenBalance?.rawAmount ?? BigInt.zero, decimals),
      address: address,
      contractAddress: asset.contractAddress,
      logoUrl: asset.logoUrl,
      canonicalTokenId: asset.canonicalTokenId,
      decimals: decimals,
    );
  }

  /// 从 Solana token account 响应项中提取 jsonParsed 的 parsed 数据。
  Map<dynamic, dynamic>? _solanaParsedAccountData(dynamic item) {
    final account = item is Map ? item['account'] : null;
    final accountData = account is Map ? account['data'] : null;
    final parsed = accountData is Map ? accountData['parsed'] : null;
    return parsed is Map ? parsed : null;
  }

  /// 查询 TRX 原生余额。
  ///
  /// TRON 账号接口返回的 balance 单位是 sun，需要按 TRX decimals 转换。
}

/// Solana SPL Token 的原始余额汇总结果。
class _SolanaTokenBalance {
  const _SolanaTokenBalance({required this.rawAmount, required this.decimals});

  /// token 最小单位数量。
  final BigInt rawAmount;

  /// token 精度，优先使用链上 token account 返回值。
  final int decimals;
}
