part of 'home_controller.dart';

extension HomeControllerValuation on HomeController {
  /// 根据当前余额计算美元估值，并更新首页头部展示。
  Future<void> refreshTotalAssets() async {
    final totalValue = await _valuationService.loadTotalUsdValue(
      visibleBalances,
    );
    totalAssetsText = _valuationService.formatUsdValue(totalValue);
    update();
  }

  /// 使用缓存价格立即刷新总资产估值。
  ///
  /// 余额刷新后先用缓存价格更新 UI，再等待网络价格返回，减少总资产长时间空白。
  void _refreshTotalAssetsFromCachedPrices() {
    final totalValue = _valuationService.calculateTotalUsdValue(
      visibleBalances,
      prices: _valuationService.cachedUsdPrices,
    );
    totalAssetsText = _valuationService.formatUsdValue(totalValue);
  }

  /// 获取单个非稳定币资产的稳定币估值文本。
  ///
  /// 稳定币本身不需要额外换算，可能返回 null。
  String? stableValueTextFor(ChainBalance balance) {
    return assetStableValueTexts[HomeControllerUtils.assetStableValueKey(
      balance,
    )];
  }

  /// 获取单条链的 USD 汇总估值文本。
  String chainUsdValueTextFor(WalletChainConfig chain) {
    return chainUsdValueTexts[chain.id] ?? '--';
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

  /// 首页最终展示的链列表。
  List<WalletChainConfig> get displayChains {
    final displayChainIds = displayBalances
        .map((balance) => balance.chainId)
        .toSet();
    if (!hideZeroBalances) {
      return chains;
    }
    return chains
        .where((chain) => displayChainIds.contains(chain.id))
        .toList(growable: false);
  }

  void setHideZeroBalances(bool value) {
    hideZeroBalances = value;
    if (value) {
      expandedChainIds
        ..clear()
        ..addAll(displayChains.map((chain) => chain.id));
    }
    update();
  }

  /// 刷新非稳定币资产换算后的稳定币估值文本。
  void _refreshAssetStableValueTexts(Map<String, Decimal> prices) {
    // 只更新价格变化的资产，减少首页刷新时的重复格式化工作。
    for (final balance in visibleBalances) {
      final symbol = balance.symbol;
      final newPrice = prices[symbol];
      final key = HomeControllerUtils.assetStableValueKey(balance);

      if (newPrice != null && _cachedPrices[symbol] != newPrice) {
        final valueText = _valuationService.formatNonStableUsdValue(
          balance,
          prices: prices,
        );
        if (valueText != null) {
          assetStableValueTexts[key] = valueText;
        }
        _cachedPrices[symbol] = newPrice;
      }
    }

    assetStableValueTexts.removeWhere(
      (key, _) => !visibleBalances.any(
        (b) => HomeControllerUtils.assetStableValueKey(b) == key,
      ),
    );
  }

  /// 按链汇总当前可见资产的 USD 估值。
  void _refreshChainUsdValueTexts(Map<String, Decimal> prices) {
    chainUsdValueTexts.clear();
    for (final chain in chains) {
      final chainBalances = visibleBalances
          .where((balance) => balance.chainId == chain.id)
          .toList(growable: false);
      final totalValue = _valuationService.calculateTotalUsdValue(
        chainBalances,
        prices: prices,
      );
      chainUsdValueTexts[chain.id] = _valuationService.formatUsdValue(
        totalValue,
      );
    }
  }

  /// 输出估值 UI 状态，便于排查移动端价格缺失或总资产异常。
  void _logValuationUiState(Map<String, Decimal> prices) {
    final buffer = StringBuffer()
      ..writeln('----- HomeController valuation UI -----')
      ..writeln('prices=$prices')
      ..writeln('totalAssetsText=$totalAssetsText')
      ..writeln('assetStableValueTexts=$assetStableValueTexts')
      ..writeln('chainUsdValueTexts=$chainUsdValueTexts');

    for (final balance in visibleBalances) {
      if (_valuationService.isStableSymbol(balance.symbol)) {
        continue;
      }
      buffer.writeln(
        '${balance.chainId}/${balance.symbol} amount=${balance.amount} '
        'text=${stableValueTextFor(balance) ?? '-'}',
      );
    }
    developer.log(buffer.toString(), name: 'HomeController');
  }

  /// 展开或收起指定链下的币种列表。
  void toggleChainExpanded(WalletChainConfig chain) {
    if (!expandedChainIds.add(chain.id)) {
      expandedChainIds.remove(chain.id);
    }
    update();
  }

  /// 判断指定链是否已展开。
  bool isChainExpanded(WalletChainConfig chain) {
    return expandedChainIds.contains(chain.id);
  }
}
