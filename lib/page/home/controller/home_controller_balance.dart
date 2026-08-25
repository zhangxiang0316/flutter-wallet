part of 'home_controller.dart';

class HomeBalanceState {
  const HomeBalanceState({
    required this.balances,
    required this.visibleBalances,
    required this.tokenPortfolioItems,
    required this.totalAssetsText,
    required this.isLoading,
    required this.balanceAsOf,
    required this.balanceSnapshotSource,
    required this.balanceRefreshStatus,
    required this.isBalanceDataStale,
    required this.balanceRefreshError,
  });

  final List<ChainBalance> balances;
  final List<ChainBalance> visibleBalances;
  final List<TokenPortfolioItem> tokenPortfolioItems;
  final String totalAssetsText;
  final bool isLoading;
  final DateTime? balanceAsOf;
  final BalanceSnapshotSource? balanceSnapshotSource;
  final BalanceRefreshStatus balanceRefreshStatus;
  final bool isBalanceDataStale;
  final String? balanceRefreshError;
}

/// Owns balance cache, network refresh, retries, timers and presentation state.
class HomeBalanceCoordinator {
  HomeBalanceCoordinator({
    required ChainBalanceService balanceService,
    required AssetValuationService valuationService,
    required ChainBalanceCache balanceCache,
    required HomePortfolioPresenter portfolioPresenter,
    required Duration retryDelay,
    required void Function(HomeBalanceState state) onStateChanged,
    required void Function() onLoadFailed,
  }) : _balanceService = balanceService,
       _valuationService = valuationService,
       _balanceCache = balanceCache,
       _portfolioPresenter = portfolioPresenter,
       _retryDelay = retryDelay,
       _onStateChanged = onStateChanged,
       _onLoadFailed = onLoadFailed;

  final ChainBalanceService _balanceService;
  final AssetValuationService _valuationService;
  final ChainBalanceCache _balanceCache;
  final HomePortfolioPresenter _portfolioPresenter;
  final Duration _retryDelay;
  final void Function(HomeBalanceState state) _onStateChanged;
  final void Function() _onLoadFailed;

  List<ChainBalance> _balances = [];
  List<ChainBalance> _visibleBalances = [];
  List<TokenPortfolioItem> _tokenPortfolioItems = [];
  String _totalAssetsText = '--';
  bool _isLoading = false;
  DateTime? _balanceAsOf;
  BalanceSnapshotSource? _balanceSnapshotSource;
  BalanceRefreshStatus _balanceRefreshStatus = BalanceRefreshStatus.idle;
  bool _isBalanceDataStale = false;
  String? _balanceRefreshError;

  Timer? _refreshTimer;
  Timer? _retryTimer;
  int _requestId = 0;

  bool get hasAutoRefresh => _refreshTimer != null;

  Map<String, Decimal> get transferUsdPrices {
    return _portfolioPresenter.transferUsdPrices(_visibleBalances);
  }

  Future<void> refresh({
    required WalletAccount wallet,
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
  }) {
    return _refresh(
      wallet: wallet,
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
      allowFailureRetry: true,
    );
  }

  Future<void> _refresh({
    required WalletAccount wallet,
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
    required bool allowFailureRetry,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    _cancelRetry();
    final requestId = ++_requestId;
    _balanceRefreshStatus = BalanceRefreshStatus.refreshing;
    _balanceRefreshError = null;
    _publish();

    try {
      await _applyCache(
        wallet: wallet,
        chains: chains,
        hiddenAssetKeys: hiddenAssetKeys,
        requestId: requestId,
      );
      if (!_isActive(requestId)) return;

      _balanceRefreshStatus = BalanceRefreshStatus.refreshing;
      _balanceRefreshError = null;
      _publish();
      final previousBalances = _balances;
      final previousAsOf = _balanceAsOf;
      final nextBalances = await _balanceService.loadBalances(
        bscAddress: wallet.bscAddress,
        tronAddress: wallet.tronAddress,
        solanaAddress: wallet.solanaAddress,
        suiAddress: wallet.suiAddress,
        aptosAddress: wallet.aptosAddress,
        bitcoinAddress: wallet.bitcoinAddress,
        enabledChains: chains,
        onChainBalances: (chainBalances) {
          if (!_isActive(requestId)) return;
          _mergeChainBalances(chainBalances);
          _updatePresentation(
            chains: chains,
            hiddenAssetKeys: hiddenAssetKeys,
            prices: _valuationService.cachedUsdPrices,
          );
          _publish();
        },
      );
      if (!_isActive(requestId)) return;

      final failedBalances = nextBalances.where((balance) => balance.hasError);
      final failedChainNames = failedBalances
          .map((balance) => balance.chainRef.name)
          .toSet();
      if (failedChainNames.isNotEmpty) {
        SafeLog.error(
          'Balance refresh failed chains: ${failedChainNames.join(', ')}',
          name: 'HomeBalanceCoordinator',
        );
      }
      final allFailed =
          nextBalances.isEmpty || failedBalances.length == nextBalances.length;
      _balances = _preserveLastSuccessfulBalances(
        nextBalances,
        previousBalances,
      );

      if (allFailed) {
        _balanceSnapshotSource = previousBalances.isEmpty
            ? BalanceSnapshotSource.network
            : _balanceSnapshotSource ?? BalanceSnapshotSource.cache;
        _balanceRefreshStatus = BalanceRefreshStatus.failure;
        _balanceRefreshError = 'balance_refresh_failed';
        _isBalanceDataStale = _balances.isNotEmpty;
        _onLoadFailed();
        if (allowFailureRetry) {
          _scheduleRetry(
            requestId: requestId,
            wallet: wallet,
            chains: chains,
            hiddenAssetKeys: hiddenAssetKeys,
          );
        }
      } else {
        final hasPartialFailure = failedBalances.isNotEmpty;
        final refreshedAt = DateTime.now();
        _balanceAsOf = hasPartialFailure && previousAsOf != null
            ? previousAsOf
            : refreshedAt;
        _balanceSnapshotSource =
            hasPartialFailure && previousBalances.isNotEmpty
            ? BalanceSnapshotSource.mixed
            : BalanceSnapshotSource.network;
        _balanceRefreshStatus = hasPartialFailure
            ? BalanceRefreshStatus.partialFailure
            : BalanceRefreshStatus.success;
        _balanceRefreshError = hasPartialFailure
            ? 'balance_refresh_partial'
            : null;
        _isBalanceDataStale = hasPartialFailure;
        if (hasPartialFailure && allowFailureRetry) {
          _scheduleRetry(
            requestId: requestId,
            wallet: wallet,
            chains: chains,
            hiddenAssetKeys: hiddenAssetKeys,
          );
        }
        await _balanceCache.save(
          wallet.id,
          ChainBalanceSnapshot(
            balances: _balances,
            asOf: _balanceAsOf!,
            source: _balanceSnapshotSource!,
            refreshStatus: _balanceRefreshStatus,
            isStale: _isBalanceDataStale,
            error: _balanceRefreshError,
          ),
        );
      }

      _updatePresentation(
        chains: chains,
        hiddenAssetKeys: hiddenAssetKeys,
        prices: _valuationService.cachedUsdPrices,
      );
      _isLoading = false;
      _publish();

      final latestPrices = await _valuationService
          .loadUsdPrices(_visibleBalances)
          .catchError((_) => _valuationService.cachedUsdPrices);
      if (!_isActive(requestId)) return;
      _updatePresentation(
        chains: chains,
        hiddenAssetKeys: hiddenAssetKeys,
        prices: latestPrices,
      );
      _publish();
    } catch (_) {
      if (_isActive(requestId)) {
        _balanceRefreshStatus = BalanceRefreshStatus.failure;
        _balanceRefreshError = 'balance_refresh_failed';
        _isBalanceDataStale = _balances.isNotEmpty;
        _onLoadFailed();
        if (allowFailureRetry) {
          _scheduleRetry(
            requestId: requestId,
            wallet: wallet,
            chains: chains,
            hiddenAssetKeys: hiddenAssetKeys,
          );
        }
      }
    } finally {
      if (_isActive(requestId)) {
        _isLoading = false;
        _publish();
      }
    }
  }

  void refreshPresentation({
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
  }) {
    _updatePresentation(
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
      prices: _valuationService.cachedUsdPrices,
    );
    _publish();
  }

  void reset() {
    _cancelRetry();
    _requestId++;
    _balances = [];
    _visibleBalances = [];
    _tokenPortfolioItems = [];
    _totalAssetsText = '--';
    _isLoading = false;
    _balanceAsOf = null;
    _balanceSnapshotSource = null;
    _balanceRefreshStatus = BalanceRefreshStatus.idle;
    _isBalanceDataStale = false;
    _balanceRefreshError = null;
    _publish();
  }

  void startAutoRefresh(Future<void> Function() refresh) {
    stopAutoRefresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(refresh());
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _cancelRetry();
  }

  Future<void> _applyCache({
    required WalletAccount wallet,
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
    required int requestId,
  }) async {
    if (!_isActive(requestId)) return;
    final snapshot = await _balanceCache.load(
      wallet.id,
      chains: chains,
      allowStale: true,
    );
    if (!_isActive(requestId) ||
        snapshot == null ||
        snapshot.balances.isEmpty) {
      return;
    }
    _balances = snapshot.balances;
    _balanceAsOf = snapshot.asOf;
    _balanceSnapshotSource = snapshot.source;
    _balanceRefreshStatus = snapshot.refreshStatus;
    _balanceRefreshError = snapshot.error;
    _isBalanceDataStale = snapshot.isStale || snapshot.hasError;
    _updatePresentation(
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
      prices: _valuationService.cachedUsdPrices,
    );
    _publish();
  }

  void _scheduleRetry({
    required int requestId,
    required WalletAccount wallet,
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
  }) {
    _cancelRetry();
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      if (!_isActive(requestId) || _isLoading) return;
      unawaited(
        _refresh(
          wallet: wallet,
          chains: chains,
          hiddenAssetKeys: hiddenAssetKeys,
          allowFailureRetry: false,
        ),
      );
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  bool _isActive(int requestId) => requestId == _requestId;

  void _mergeChainBalances(List<ChainBalance> chainBalances) {
    if (chainBalances.isEmpty) return;
    final updatedChainIds = chainBalances
        .map((balance) => balance.chainId)
        .toSet();
    final resolvedBalances = _preserveLastSuccessfulBalances(
      chainBalances,
      _balances,
    );
    _balances = [
      ..._balances.where(
        (balance) => !updatedChainIds.contains(balance.chainId),
      ),
      ...resolvedBalances,
    ];
  }

  List<ChainBalance> _preserveLastSuccessfulBalances(
    List<ChainBalance> freshBalances,
    List<ChainBalance> previousBalances,
  ) {
    final previousByKey = {
      for (final balance in previousBalances) _balanceKey(balance): balance,
    };
    return freshBalances
        .map(
          (balance) => balance.hasError
              ? previousByKey[_balanceKey(balance)] ?? balance
              : balance,
        )
        .toList(growable: false);
  }

  String _balanceKey(ChainBalance balance) {
    final contract = balance.contractAddress?.trim() ?? '';
    final normalizedContract = balance.chainRef.isEvm
        ? contract.toLowerCase()
        : contract;
    return '${balance.chainId}:$normalizedContract:${balance.symbol}';
  }

  void _updatePresentation({
    required List<WalletChainConfig> chains,
    required Set<String> hiddenAssetKeys,
    required Map<String, Decimal> prices,
  }) {
    final presentation = _portfolioPresenter.present(
      balances: _balances,
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
      prices: prices,
    );
    _visibleBalances = presentation.visibleBalances;
    _tokenPortfolioItems = presentation.tokenPortfolioItems;
    _totalAssetsText = presentation.totalAssetsText;
  }

  void _publish() {
    _onStateChanged(
      HomeBalanceState(
        balances: List.unmodifiable(_balances),
        visibleBalances: List.unmodifiable(_visibleBalances),
        tokenPortfolioItems: List.unmodifiable(_tokenPortfolioItems),
        totalAssetsText: _totalAssetsText,
        isLoading: _isLoading,
        balanceAsOf: _balanceAsOf,
        balanceSnapshotSource: _balanceSnapshotSource,
        balanceRefreshStatus: _balanceRefreshStatus,
        isBalanceDataStale: _isBalanceDataStale,
        balanceRefreshError: _balanceRefreshError,
      ),
    );
  }
}
