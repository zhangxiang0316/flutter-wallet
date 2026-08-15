part of 'home_controller.dart';

extension HomeControllerValuation on HomeController {
  /// 根据最新余额和价格重新生成首页代币组合。
  void _refreshTokenPortfolioItems(Map<String, Decimal> prices) {
    tokenPortfolioItems = _tokenPortfolioService.build(
      balances: visibleBalances,
      chains: chains,
      prices: prices,
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
