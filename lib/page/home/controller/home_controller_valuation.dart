part of 'home_controller.dart';

extension HomeControllerValuation on HomeController {
  /// 根据当前余额计算美元估值，并更新首页头部展示。
  Future<void> refreshTotalAssets() async {
    final prices = await _valuationService.loadUsdPrices(visibleBalances);
    _refreshTokenPortfolioItems(prices);
    update();
  }

  /// 首页最终展示的资产列表。
  ///
  /// [visibleBalances] 只受资产显示设置影响；这里再叠加隐藏 0 余额，
  /// 避免临时展示过滤影响总资产估值和转账可选资产范围。
  List<ChainBalance> get displayBalances {
    if (!hideZeroBalances) return visibleBalances;
    return visibleBalances
        .where(
          (balance) =>
              balance.hasError ||
              !HomeControllerUtils.isZeroAmount(balance.amount),
        )
        .toList(growable: false);
  }

  void setHideZeroBalances(bool value) {
    hideZeroBalances = value;
    _refreshTokenPortfolioItems(_valuationService.cachedUsdPrices);
    update();
  }

  /// 根据最新余额和价格重新生成首页代币组合。
  void _refreshTokenPortfolioItems(Map<String, Decimal> prices) {
    tokenPortfolioItems = _tokenPortfolioService.build(
      balances: visibleBalances,
      chains: chains,
      prices: prices,
      hideZeroBalances: hideZeroBalances,
    );
    var total = Decimal.zero;
    var hasValue = false;
    for (final item in tokenPortfolioItems) {
      final value = item.totalUsdValue;
      if (value == null) continue;
      total += value;
      hasValue = true;
    }
    totalAssetsText = _valuationService.formatUsdValue(hasValue ? total : null);
  }
}
