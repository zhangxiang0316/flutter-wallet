part of 'home_controller.dart';

class HomePortfolioPresentation {
  const HomePortfolioPresentation({
    required this.visibleBalances,
    required this.tokenPortfolioItems,
    required this.totalAssetsText,
  });

  final List<ChainBalance> visibleBalances;
  final List<TokenPortfolioItem> tokenPortfolioItems;
  final String totalAssetsText;
}

/// Converts domain balances into the state consumed by the home page.
class HomePortfolioPresenter {
  HomePortfolioPresenter({
    required WalletAssetVisibilityService assetVisibilityService,
    required TokenPortfolioService tokenPortfolioService,
    required AssetValuationService valuationService,
  }) : _assetVisibilityService = assetVisibilityService,
       _tokenPortfolioService = tokenPortfolioService,
       _valuationService = valuationService;

  final WalletAssetVisibilityService _assetVisibilityService;
  final TokenPortfolioService _tokenPortfolioService;
  final AssetValuationService _valuationService;

  HomePortfolioPresentation present({
    required List<ChainBalance> balances,
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
    required Map<String, Decimal> prices,
  }) {
    final visibleBalances = balances
        .where(
          (balance) => _assetVisibilityService.isBalanceVisible(
            balance,
            hiddenAssetKeys,
          ),
        )
        .toList(growable: false);
    final items = _tokenPortfolioService.build(
      balances: visibleBalances,
      chains: chains,
      prices: prices,
    );
    var total = Decimal.zero;
    var hasValue = false;
    for (final item in items) {
      final value = item.totalUsdValue;
      if (value == null) continue;
      total += value;
      hasValue = true;
    }
    return HomePortfolioPresentation(
      visibleBalances: visibleBalances,
      tokenPortfolioItems: items,
      totalAssetsText: _valuationService.formatUsdValue(
        hasValue ? total : null,
      ),
    );
  }

  Map<String, Decimal> transferUsdPrices(List<ChainBalance> balances) {
    final prices = <String, Decimal>{};
    for (final balance in balances) {
      final price = _valuationService.priceForSymbol(
        balance.symbol,
        _valuationService.cachedUsdPrices,
      );
      if (price != null) prices[balance.symbol.toUpperCase()] = price;
    }
    return Map.unmodifiable(prices);
  }
}
