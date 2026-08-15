part of 'home_controller.dart';

extension HomeControllerBalance on HomeController {
  /// 查询多条链的资产余额。
  ///
  /// 优化策略：
  /// 1. 立即显示缓存余额；
  /// 2. 后台静默更新最新数据；
  /// 3. 更新完成后刷新 UI 并保存新缓存。
  Future<void> refreshBalances() async {
    final currentWallet = wallet;
    if (currentWallet == null) return;
    if (isLoading) return;

    final requestId = ++_balanceRequestId;
    await _applyCachedBalances(currentWallet);

    isLoading = true;
    update();

    try {
      final nextBalances = await _balanceService.loadBalances(
        bscAddress: currentWallet.bscAddress,
        tronAddress: currentWallet.tronAddress,
        solanaAddress: currentWallet.solanaAddress,
        suiAddress: currentWallet.suiAddress,
        aptosAddress: currentWallet.aptosAddress,
        bitcoinAddress: currentWallet.bitcoinAddress,
      );
      if (!_isActiveBalanceRequest(requestId, currentWallet)) {
        return;
      }

      balances = nextBalances;
      await _balanceCache.save(currentWallet.id, nextBalances);
      await _refreshBalanceDisplayState();
      isLoading = false;
      update();

      final latestPrices = await _valuationService
          .loadUsdPrices(visibleBalances)
          .catchError((_) => _valuationService.cachedUsdPrices);
      if (!_isActiveBalanceRequest(requestId, currentWallet)) {
        return;
      }
      _refreshTokenPortfolioItems(latestPrices);
      update();
    } catch (_) {
      if (_isActiveBalanceRequest(requestId, currentWallet)) {
        Toast.show(S.current.balanceLoadFailed);
      }
    } finally {
      if (_isActiveBalanceRequest(requestId, currentWallet)) {
        isLoading = false;
        update();
      }
    }
  }

  Future<void> _applyCachedBalances(WalletAccount currentWallet) async {
    final cachedBalances = await _balanceCache.load(currentWallet.id);
    if (cachedBalances == null || cachedBalances.isEmpty) {
      return;
    }
    balances = cachedBalances;
    await _refreshBalanceDisplayState();
    update();
  }

  Future<void> _refreshBalanceDisplayState() async {
    hiddenAssetKeys = await _assetVisibilityService.loadHiddenAssetKeys();
    chains = await _chainConfigService.loadEnabledChains();
    _applyAssetVisibility();
    _refreshTokenPortfolioItems(_valuationService.cachedUsdPrices);
  }

  bool _isActiveBalanceRequest(int requestId, WalletAccount currentWallet) {
    return requestId == _balanceRequestId && wallet?.id == currentWallet.id;
  }

  /// 清空当前钱包相关 UI 状态。
  ///
  /// 切换或删除钱包时调用，防止旧钱包余额和估值短暂显示在新钱包下。
  void _resetWalletState() {
    _balanceRequestId++;
    balances = [];
    visibleBalances = [];
    tokenPortfolioItems = [];
    totalAssetsText = '--';
    isLoading = false;
  }

  /// 根据用户资产显示配置过滤余额列表。
  void _applyAssetVisibility() {
    visibleBalances = balances
        .where(
          (balance) => _assetVisibilityService.isBalanceVisible(
            balance,
            hiddenAssetKeys,
          ),
        )
        .toList(growable: false);
  }
}
