import 'dart:async';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/asset_valuation_service.dart';
import '../../../wallet/services/chain_balance_service.dart';
import '../../../wallet/services/wallet_crypto_service.dart';
import '../../../wallet/services/wallet_repository.dart';

class HomeController extends BaseController {
  HomeController({
    WalletRepository? repository,
    WalletCryptoService? cryptoService,
    ChainBalanceService? balanceService,
    AssetValuationService? valuationService,
  }) : _repository = repository ?? WalletRepository(),
       _cryptoService = cryptoService ?? WalletCryptoService(),
       _balanceService = balanceService ?? ChainBalanceService(),
       _valuationService = valuationService ?? AssetValuationService();

  final WalletRepository _repository;
  final WalletCryptoService _cryptoService;
  final ChainBalanceService _balanceService;
  final AssetValuationService _valuationService;

  /// 当前本地钱包；为空时首页展示创建/导入入口。
  WalletAccount? wallet;

  /// 多链资产余额列表，由 [ChainBalanceService] 从链上查询。
  List<ChainBalance> balances = [];

  /// 已格式化的总资产估值文本。价格源不可用时显示 `--`。
  String totalAssetsText = '--';

  /// 防止重复发起余额刷新，并驱动刷新按钮和链卡片 loading 状态。
  bool isLoading = false;

  /// 当前已展开的链。默认空集合，首页只展示链信息。
  final Set<String> expandedChainIds = {};

  Timer? _balanceRefreshTimer;

  @override
  void onInit() {
    super.onInit();
    loadWallet();
  }

  /// 启动时读取本地钱包；如果存在钱包，立即拉取链上余额。
  Future<void> loadWallet() async {
    wallet = await _repository.loadWallet();
    update();
    if (wallet != null) {
      _startBalanceRefreshTimer();
      refreshBalances();
    }
  }

  /// 随机生成私钥并创建测试钱包，保存后刷新链上余额。
  Future<void> createWallet() async {
    final keyPair = _cryptoService.importPrivateKey(
      _cryptoService.generatePrivateKeyHex(),
    );
    wallet = WalletAccount(
      name: 'Wallet 1',
      privateKeyHex: keyPair.privateKeyHex,
      bscAddress: keyPair.bscAddress,
      tronAddress: keyPair.tronAddress,
      createdAt: DateTime.now(),
    );
    balances = [];
    totalAssetsText = '--';
    await _repository.saveWallet(wallet!);
    update();
    Toast.show(S.current.walletCreated);
    _startBalanceRefreshTimer();
    refreshBalances();
  }

  /// 导入用户输入的私钥，派生 EVM/TRON 地址并保存到本地。
  Future<bool> importWallet(String privateKey) async {
    try {
      final keyPair = _cryptoService.importPrivateKey(privateKey);
      wallet = WalletAccount(
        name: 'Imported Wallet',
        privateKeyHex: keyPair.privateKeyHex,
        bscAddress: keyPair.bscAddress,
        tronAddress: keyPair.tronAddress,
        createdAt: DateTime.now(),
      );
      balances = [];
      totalAssetsText = '--';
      await _repository.saveWallet(wallet!);
      update();
      Toast.show(S.current.walletImported);
      _startBalanceRefreshTimer();
      refreshBalances();
      return true;
    } catch (_) {
      Toast.show(S.current.invalidPrivateKey);
      return false;
    }
  }

  /// 查询多条链的资产余额。余额先更新到 UI，再异步刷新总资产估值。
  Future<void> refreshBalances() async {
    final currentWallet = wallet;
    if (currentWallet == null || isLoading) return;
    isLoading = true;
    update();

    final priceFuture = _valuationService.loadSupportedUsdPrices().catchError(
      (_) => _valuationService.cachedUsdPrices,
    );

    balances = await _balanceService.loadBalances(
      bscAddress: currentWallet.bscAddress,
      tronAddress: currentWallet.tronAddress,
    );
    _refreshTotalAssetsFromCachedPrices();
    isLoading = false;
    update();

    final latestPrices = await priceFuture;
    final totalValue = _valuationService.calculateTotalUsdValue(
      balances,
      prices: latestPrices,
    );
    totalAssetsText = _valuationService.formatUsdValue(totalValue);
    update();
  }

  /// 根据当前余额计算美元估值，并更新首页头部展示。
  Future<void> refreshTotalAssets() async {
    final totalValue = await _valuationService.loadTotalUsdValue(balances);
    totalAssetsText = _valuationService.formatUsdValue(totalValue);
    update();
  }

  void _refreshTotalAssetsFromCachedPrices() {
    final totalValue = _valuationService.calculateTotalUsdValue(
      balances,
      prices: _valuationService.cachedUsdPrices,
    );
    totalAssetsText = _valuationService.formatUsdValue(totalValue);
  }

  void toggleChainExpanded(WalletChain chain) {
    if (!expandedChainIds.add(chain.id)) {
      expandedChainIds.remove(chain.id);
    }
    update();
  }

  bool isChainExpanded(WalletChain chain) {
    return expandedChainIds.contains(chain.id);
  }

  /// 删除本地钱包和页面状态，不触发任何链上操作。
  Future<void> removeWallet() async {
    _stopBalanceRefreshTimer();
    await _repository.clearWallet();
    wallet = null;
    balances = [];
    expandedChainIds.clear();
    totalAssetsText = '--';
    update();
    Toast.show(S.current.walletRemoved);
  }

  void _startBalanceRefreshTimer() {
    _stopBalanceRefreshTimer();
    _balanceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshBalances();
    });
  }

  void _stopBalanceRefreshTimer() {
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = null;
  }

  @override
  void onClose() {
    _stopBalanceRefreshTimer();
    super.onClose();
  }
}
