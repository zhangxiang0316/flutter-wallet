part of 'home_controller.dart';

extension HomeControllerBalance on HomeController {
  /// 查询多条链的资产余额。
  ///
  /// 优化策略：
  /// 1. 立即显示缓存余额；
  /// 2. 后台静默更新最新数据；
  /// 3. 每条链完成后立即合并并局部刷新 UI；
  /// 4. 全部完成后保存完整快照并更新价格。
  Future<void> refreshBalances() async {
    final currentWallet = wallet;
    if (currentWallet == null) return;
    if (isLoading) return;

    final requestId = ++_balanceRequestId;
    await _applyCachedBalances(currentWallet);

    isLoading = true;
    balanceRefreshStatus = BalanceRefreshStatus.refreshing;
    balanceRefreshError = null;
    _updateBalanceView();

    try {
      final previousBalances = balances;
      final previousAsOf = balanceAsOf;
      final nextBalances = await _balanceService.loadBalances(
        bscAddress: currentWallet.bscAddress,
        tronAddress: currentWallet.tronAddress,
        solanaAddress: currentWallet.solanaAddress,
        suiAddress: currentWallet.suiAddress,
        aptosAddress: currentWallet.aptosAddress,
        bitcoinAddress: currentWallet.bitcoinAddress,
        onChainBalances: (chainBalances) {
          if (!_isActiveBalanceRequest(requestId, currentWallet)) {
            return;
          }
          _mergeChainBalances(chainBalances);
          _applyAssetVisibility();
          _refreshTokenPortfolioItems(_valuationService.cachedUsdPrices);
          _updateBalanceView();
        },
      );
      if (!_isActiveBalanceRequest(requestId, currentWallet)) {
        return;
      }

      final failedBalances = nextBalances.where((balance) => balance.hasError);
      final allFailed =
          nextBalances.isEmpty || failedBalances.length == nextBalances.length;
      balances = _preserveLastSuccessfulBalances(
        nextBalances,
        previousBalances,
      );

      if (allFailed) {
        balanceSnapshotSource = previousBalances.isEmpty
            ? BalanceSnapshotSource.network
            : balanceSnapshotSource ?? BalanceSnapshotSource.cache;
        balanceRefreshStatus = BalanceRefreshStatus.failure;
        balanceRefreshError = 'balance_refresh_failed';
        isBalanceDataStale = balances.isNotEmpty;
        Toast.show(S.current.balanceLoadFailed);
      } else {
        final hasPartialFailure = failedBalances.isNotEmpty;
        final refreshedAt = DateTime.now();
        balanceAsOf = hasPartialFailure && previousAsOf != null
            ? previousAsOf
            : refreshedAt;
        balanceSnapshotSource = hasPartialFailure && previousBalances.isNotEmpty
            ? BalanceSnapshotSource.mixed
            : BalanceSnapshotSource.network;
        balanceRefreshStatus = hasPartialFailure
            ? BalanceRefreshStatus.partialFailure
            : BalanceRefreshStatus.success;
        balanceRefreshError = hasPartialFailure
            ? 'balance_refresh_partial'
            : null;
        isBalanceDataStale = hasPartialFailure;
        await _balanceCache.save(
          currentWallet.id,
          ChainBalanceSnapshot(
            balances: balances,
            asOf: balanceAsOf!,
            source: balanceSnapshotSource!,
            refreshStatus: balanceRefreshStatus,
            isStale: isBalanceDataStale,
            error: balanceRefreshError,
          ),
        );
      }
      await _refreshBalanceDisplayState();
      isLoading = false;
      _updateBalanceView();

      final latestPrices = await _valuationService
          .loadUsdPrices(visibleBalances)
          .catchError((_) => _valuationService.cachedUsdPrices);
      if (!_isActiveBalanceRequest(requestId, currentWallet)) {
        return;
      }
      _refreshTokenPortfolioItems(latestPrices);
      _updateBalanceView();
    } catch (_) {
      if (_isActiveBalanceRequest(requestId, currentWallet)) {
        balanceRefreshStatus = BalanceRefreshStatus.failure;
        balanceRefreshError = 'balance_refresh_failed';
        isBalanceDataStale = balances.isNotEmpty;
        Toast.show(S.current.balanceLoadFailed);
      }
    } finally {
      if (_isActiveBalanceRequest(requestId, currentWallet)) {
        isLoading = false;
        _updateBalanceView();
      }
    }
  }

  Future<void> _applyCachedBalances(WalletAccount currentWallet) async {
    final currentChains = await _chainConfigService.loadEnabledChains();
    chains = currentChains;
    final snapshot = await _balanceCache.load(
      currentWallet.id,
      chains: currentChains,
      allowStale: true,
    );
    if (snapshot == null || snapshot.balances.isEmpty) {
      return;
    }
    balances = snapshot.balances;
    balanceAsOf = snapshot.asOf;
    balanceSnapshotSource = snapshot.source;
    balanceRefreshStatus = snapshot.refreshStatus;
    balanceRefreshError = snapshot.error;
    isBalanceDataStale = snapshot.isStale || snapshot.hasError;
    await _refreshBalanceDisplayState();
    _updateBalanceView();
  }

  /// 用某条链的新结果替换缓存中的旧结果，不影响其它仍在请求中的链。
  void _mergeChainBalances(List<ChainBalance> chainBalances) {
    if (chainBalances.isEmpty) return;
    final updatedChainIds = chainBalances
        .map((balance) => balance.chainId)
        .toSet();
    final resolvedBalances = _preserveLastSuccessfulBalances(
      chainBalances,
      balances,
    );
    balances = [
      ...balances.where(
        (balance) => !updatedChainIds.contains(balance.chainId),
      ),
      ...resolvedBalances,
    ];
  }

  /// 网络失败时保留同一资产最后一次成功余额，避免离线刷新把缓存覆盖成 0。
  List<ChainBalance> _preserveLastSuccessfulBalances(
    List<ChainBalance> freshBalances,
    List<ChainBalance> previousBalances,
  ) {
    final previousByKey = {
      for (final balance in previousBalances) _balanceKey(balance): balance,
    };
    return freshBalances
        .map((balance) {
          if (!balance.hasError) return balance;
          return previousByKey[_balanceKey(balance)] ?? balance;
        })
        .toList(growable: false);
  }

  String _balanceKey(ChainBalance balance) {
    final contract = balance.contractAddress?.trim() ?? '';
    final normalizedContract = balance.chainRef.isEvm
        ? contract.toLowerCase()
        : contract;
    return '${balance.chainId}:$normalizedContract:${balance.symbol}';
  }

  void _updateBalanceView() {
    update([HomeController.balanceViewId]);
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
    balanceAsOf = null;
    balanceSnapshotSource = null;
    balanceRefreshStatus = BalanceRefreshStatus.idle;
    isBalanceDataStale = false;
    balanceRefreshError = null;
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
