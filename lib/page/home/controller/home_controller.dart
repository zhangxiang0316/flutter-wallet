import 'dart:async';

import 'package:decimal/decimal.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/password_cache_service.dart';
import '../../../utils/toast_util.dart';
import '../../../utils/safe_log.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/token_portfolio.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/asset_valuation_service.dart';
import '../../../wallet/services/chain_balance_cache.dart';
import '../../../wallet/services/chain_balance_service.dart';
import '../../../wallet/services/token_portfolio_service.dart';
import '../../../wallet/services/config/wallet_asset_visibility_service.dart';
import '../../../wallet/services/config/wallet_backup_status_service.dart';
import '../../../wallet/services/config/wallet_chain_config_service.dart';
import '../../../wallet/services/crypto/wallet_crypto_service.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/crypto/wallet_secret_store.dart';
import 'home_controller_utils.dart';

part 'home_controller_valuation.dart';
part 'home_controller_balance.dart';
part 'home_wallet_lifecycle_service.dart';
part 'home_wallet_migration_service.dart';
part 'home_wallet_address_upgrade_service.dart';

/// 首页控制器。
///
/// 组合钱包生命周期、迁移、地址升级、余额协调和资产展示服务，并向页面暴露状态。
class HomeController extends BaseController {
  /// 余额和估值区域的局部刷新 ID，避免每条链返回时重建整个 Scaffold。
  static const String balanceViewId = 'home-balance-view';

  HomeController({
    WalletRepository? repository,
    WalletCryptoService? cryptoService,
    ChainBalanceService? balanceService,
    AssetValuationService? valuationService,
    WalletAssetVisibilityService? assetVisibilityService,
    WalletBackupStatusService? backupStatusService,
    WalletChainConfigService? chainConfigService,
    ChainBalanceCache? balanceCache,
    TokenPortfolioService? tokenPortfolioService,
    Duration balanceRetryDelay = const Duration(seconds: 2),
  }) {
    final resolvedRepository = repository ?? WalletRepository();
    final resolvedCryptoService = cryptoService ?? WalletCryptoService();
    final resolvedValuationService =
        valuationService ?? AssetValuationService();
    final resolvedVisibilityService =
        assetVisibilityService ?? WalletAssetVisibilityService();
    final addressUpgradeService = WalletAddressUpgradeService(
      repository: resolvedRepository,
      cryptoService: resolvedCryptoService,
    );
    _assetVisibilityService = resolvedVisibilityService;
    _chainConfigService = chainConfigService ?? WalletChainConfigService();
    _walletLifecycleService = WalletLifecycleService(
      repository: resolvedRepository,
      cryptoService: resolvedCryptoService,
      backupStatusService: backupStatusService ?? WalletBackupStatusService(),
    );
    _walletMigrationService = WalletMigrationService(
      repository: resolvedRepository,
      addressUpgradeService: addressUpgradeService,
    );
    _walletAddressUpgradeService = addressUpgradeService;
    final portfolioPresenter = HomePortfolioPresenter(
      assetVisibilityService: resolvedVisibilityService,
      tokenPortfolioService: tokenPortfolioService ?? TokenPortfolioService(),
      valuationService: resolvedValuationService,
    );
    _balanceCoordinator = HomeBalanceCoordinator(
      balanceService: balanceService ?? ChainBalanceService(),
      valuationService: resolvedValuationService,
      balanceCache: balanceCache ?? ChainBalanceCache(),
      portfolioPresenter: portfolioPresenter,
      retryDelay: balanceRetryDelay,
      onStateChanged: _applyBalanceState,
      onLoadFailed: () => Toast.show(S.current.balanceLoadFailed),
    );
  }

  late final WalletLifecycleService _walletLifecycleService;
  late final WalletMigrationService _walletMigrationService;
  late final WalletAddressUpgradeService _walletAddressUpgradeService;
  late final HomeBalanceCoordinator _balanceCoordinator;
  late final WalletAssetVisibilityService _assetVisibilityService;
  late final WalletChainConfigService _chainConfigService;

  /// 本地保存的钱包列表。
  List<WalletAccount> wallets = [];

  /// 当前选中的钱包；为空时首页展示创建/导入入口。
  WalletAccount? wallet;

  /// 多链资产余额列表，由 [ChainBalanceService] 从链上查询。
  List<ChainBalance> balances = [];

  /// 当前启用的链配置。内置链和用户添加的 EVM 链都会进入这里。
  List<WalletChainConfig> chains = [];

  /// 按用户资产显示设置过滤后的余额列表。
  ///
  /// 首页链资产区域和总资产估值都基于该列表计算，隐藏资产不会参与展示和汇总。
  List<ChainBalance> visibleBalances = [];

  /// 首页按可信代币身份聚合后的资产组合。
  List<TokenPortfolioItem> tokenPortfolioItems = [];

  /// 当前被用户隐藏的资产 key 集合。
  ///
  /// key 的生成规则由 [WalletAssetVisibilityService] 维护，控制器只负责读取和传递。
  Set<String> hiddenAssetKeys = {};

  /// 已格式化的总资产估值文本。价格源不可用时显示 `--`。
  String totalAssetsText = '--';

  /// 防止重复发起余额刷新，并驱动刷新按钮和链卡片 loading 状态。
  bool isLoading = false;

  /// 当前展示余额对应的数据时间。
  DateTime? balanceAsOf;

  /// 当前展示余额来自网络、缓存或两者混合。
  BalanceSnapshotSource? balanceSnapshotSource;

  /// 当前余额刷新状态。
  BalanceRefreshStatus balanceRefreshStatus = BalanceRefreshStatus.idle;

  /// 当前余额是否包含超过有效期或刷新失败后保留的旧数据。
  bool isBalanceDataStale = false;

  /// 最近一次刷新错误代码，仅用于驱动明确的错误状态，不直接展示底层异常。
  String? balanceRefreshError;

  /// 首次进入首页且尚无任何可展示的余额/资产数据时为 true。
  ///
  /// 该状态只用于代币列表骨架；钱包卡片和安全提示始终立即展示。
  /// 一旦有缓存或任意链数据落地，就回到正常资产列表。
  bool get isFirstLoading => isLoading && tokenPortfolioItems.isEmpty;

  /// 转账风险检查可复用的最近 USD 单价。
  ///
  /// 稳定币由估值服务补为 1，避免转账页面再次请求行情接口。
  Map<String, Decimal> get transferUsdPrices {
    return _balanceCoordinator.transferUsdPrices;
  }

  /// 旧版本钱包仍含明文私钥时为 true，需要先设置密码完成迁移。
  bool needsSecretMigration = false;

  /// 是否正在执行旧钱包明文私钥加密迁移。
  bool isMigratingSecrets = false;

  /// 旧钱包缺少后续新增链地址时为 true，需要输入密码补派生地址。
  bool needsChainAddressUpgrade = false;

  /// 是否正在为旧钱包补全链地址。
  bool isUpgradingChainAddresses = false;

  @override
  void onInit() {
    super.onInit();
    loadWallet();
  }

  /// 启动时读取本地钱包；如果存在钱包，立即拉取当前钱包的链上余额。
  Future<void> loadWallet() async {
    final results = await Future.wait<Object>([
      _assetVisibilityService.loadHiddenAssetKeys(),
      _chainConfigService.loadEnabledChains(),
      _walletLifecycleService.loadSnapshot(),
    ]);
    hiddenAssetKeys = results[0] as Set<String>;
    chains = results[1] as List<WalletChainConfig>;
    final walletSnapshot = results[2] as WalletSnapshot;
    wallets = walletSnapshot.wallets;
    wallet = walletSnapshot.currentWallet;
    _updateWalletMaintenanceState();
    _balanceCoordinator.refreshPresentation(
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
    );
    update();
    if (wallet != null) {
      _balanceCoordinator.startAutoRefresh(refreshBalances);
      unawaited(refreshBalances());
    }
  }

  /// 同步钱包元数据和资产显示配置。
  ///
  /// 从设置页或钱包详情页返回首页时调用，确保钱包名称、隐藏资产和总资产估值
  /// 都用最新本地配置重新渲染。
  Future<void> syncWalletMetadata() async {
    hiddenAssetKeys = await _assetVisibilityService.loadHiddenAssetKeys();
    chains = await _chainConfigService.loadEnabledChains();
    final currentWalletId = wallet?.id;
    final snapshot = await _walletLifecycleService.reloadKeepingSelection(
      currentWalletId: currentWalletId,
      fallbackWallet: wallet,
    );
    _applyWalletSnapshot(snapshot);
    _balanceCoordinator.refreshPresentation(
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
    );
    update();
  }

  /// 生成助记词并创建钱包，保存后刷新链上余额。
  Future<CreatedWalletBackup?> createWallet(String password) async {
    try {
      final result = await _walletLifecycleService.create(
        password: password,
        walletCount: wallets.length,
      );
      _applyWalletSnapshot(
        WalletSnapshot(wallets: result.wallets, currentWallet: result.wallet),
      );
      _activateCurrentWallet();
      Toast.show(S.current.walletCreated);
      return CreatedWalletBackup(
        walletId: result.wallet.id,
        mnemonic: result.mnemonic,
      );
    } catch (error, stackTrace) {
      SafeLog.error(
        'Wallet creation failed',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
      Toast.show(S.current.walletCreateFailed);
      return null;
    }
  }

  /// 导入用户输入的私钥，派生 EVM/TRON 地址并保存到本地。
  Future<bool> importPrivateKeyWallet(
    String privateKey,
    String password,
  ) async {
    try {
      final snapshot = await _walletLifecycleService.importPrivateKey(
        privateKey: privateKey,
        password: password,
        currentWallets: wallets,
      );
      _applyWalletSnapshot(snapshot);
      _activateCurrentWallet();
      Toast.show(S.current.walletImported);
      return true;
    } catch (_) {
      Toast.show(S.current.invalidPrivateKey);
      return false;
    }
  }

  /// 使用助记词导入钱包。
  ///
  /// 助记词会派生出 EVM、TRON 和 Solana 地址，并把私钥/助记词加密保存到本地。
  Future<bool> importMnemonicWallet(String mnemonic, String password) async {
    try {
      final snapshot = await _walletLifecycleService.importMnemonic(
        mnemonic: mnemonic,
        password: password,
        currentWallets: wallets,
      );
      _applyWalletSnapshot(snapshot);
      _activateCurrentWallet();
      Toast.show(S.current.walletImported);
      return true;
    } catch (_) {
      Toast.show(S.current.invalidMnemonic);
      return false;
    }
  }

  /// 将旧版本明文私钥迁移为本地加密存储。
  ///
  /// 迁移成功后会顺带为缺少新增链地址的旧钱包补齐地址，避免用户还要再走
  /// 一次解锁流程。
  Future<bool> migrateLegacySecrets(String password) async {
    if (isMigratingSecrets) return false;
    try {
      isMigratingSecrets = true;
      update();
      final snapshot = await _walletMigrationService.migrateLegacySecrets(
        password: password,
        wallets: wallets,
        selectedWalletId: wallet?.id,
      );
      _applyWalletSnapshot(snapshot);
      Toast.show(S.current.walletSecurityMigrated);
      update();
      return true;
    } catch (_) {
      Toast.show(S.current.walletSecurityMigrationFailed);
      return false;
    } finally {
      isMigratingSecrets = false;
      update();
    }
  }

  /// 为旧钱包补派生缺失的链地址。
  ///
  /// 该流程需要用户输入钱包密码以读取加密私钥，完成后会刷新余额。
  Future<bool> upgradeMissingChainAddresses(String password) async {
    if (isUpgradingChainAddresses) return false;
    try {
      isUpgradingChainAddresses = true;
      update();
      final snapshot = await _walletAddressUpgradeService
          .upgradeMissingAddresses(
            password: password,
            selectedWalletId: wallet?.id,
          );
      _applyWalletSnapshot(snapshot);
      Toast.show(S.current.walletSolanaAddressUpgraded);
      update();
      unawaited(refreshBalances());
      return true;
    } on WalletSecretMissingException {
      Toast.show(S.current.walletSecretMissing);
      return false;
    } on WalletSecretInvalidPasswordException {
      Toast.show(S.current.invalidWalletPassword);
      return false;
    } catch (_) {
      Toast.show(S.current.walletSolanaAddressUpgradeFailed);
      return false;
    } finally {
      isUpgradingChainAddresses = false;
      update();
    }
  }

  /// 切换当前钱包。
  ///
  /// 切换后会清空旧余额、重启 60 秒刷新定时器，并立即请求新钱包余额。
  Future<void> switchWallet(WalletAccount nextWallet) async {
    if (wallet?.id == nextWallet.id) return;
    await _walletLifecycleService.select(nextWallet);
    wallet = nextWallet;
    _updateWalletMaintenanceState();
    _balanceCoordinator.reset();
    update();
    _balanceCoordinator.startAutoRefresh(refreshBalances);
    unawaited(refreshBalances());
  }

  /// 删除当前钱包和页面状态，不触发任何链上操作。
  Future<void> removeWallet([WalletAccount? targetWallet]) async {
    final walletToRemove = targetWallet ?? wallet;
    if (walletToRemove == null) return;
    final removedCurrentWallet = wallet?.id == walletToRemove.id;
    _applyWalletSnapshot(await _walletLifecycleService.remove(walletToRemove));
    if (removedCurrentWallet) {
      _balanceCoordinator.reset();
      update();
      if (wallet == null) {
        _balanceCoordinator.stopAutoRefresh();
      } else {
        _balanceCoordinator.startAutoRefresh(refreshBalances);
        unawaited(refreshBalances());
      }
    } else {
      update();
    }
    Toast.show(S.current.walletRemoved);
  }

  /// 刷新当前钱包余额，具体缓存、网络、重试和估值流程由协调器负责。
  Future<void> refreshBalances() {
    final currentWallet = wallet;
    if (currentWallet == null) return Future.value();
    return _balanceCoordinator.refresh(
      wallet: currentWallet,
      chains: chains,
      hiddenAssetKeys: hiddenAssetKeys,
    );
  }

  void _applyWalletSnapshot(WalletSnapshot snapshot) {
    wallets = snapshot.wallets;
    wallet = snapshot.currentWallet;
    _updateWalletMaintenanceState();
  }

  void _activateCurrentWallet() {
    _balanceCoordinator.reset();
    update();
    if (wallet == null) {
      _balanceCoordinator.stopAutoRefresh();
      return;
    }
    _balanceCoordinator.startAutoRefresh(refreshBalances);
    unawaited(refreshBalances());
  }

  void _applyBalanceState(HomeBalanceState state) {
    balances = state.balances;
    visibleBalances = state.visibleBalances;
    tokenPortfolioItems = state.tokenPortfolioItems;
    totalAssetsText = state.totalAssetsText;
    isLoading = state.isLoading;
    balanceAsOf = state.balanceAsOf;
    balanceSnapshotSource = state.balanceSnapshotSource;
    balanceRefreshStatus = state.balanceRefreshStatus;
    isBalanceDataStale = state.isBalanceDataStale;
    balanceRefreshError = state.balanceRefreshError;
    update([balanceViewId]);
  }

  /// 根据当前钱包列表更新需要用户处理的兼容性状态。
  void _updateWalletMaintenanceState() {
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsChainAddressUpgrade = HomeControllerUtils.needsChainAddressUpgrade(
      wallet,
    );
  }

  /// 页面可见时恢复定时刷新。
  @override
  void onPageVisible() {
    super.onPageVisible();
    if (wallet == null) return;
    if (!_balanceCoordinator.hasAutoRefresh) {
      _balanceCoordinator.startAutoRefresh(refreshBalances);
    }
    unawaited(refreshBalances());
  }

  /// 页面不可见时暂停定时刷新，节省资源。
  @override
  void onPageInVisible() {
    super.onPageInVisible();
    _balanceCoordinator.stopAutoRefresh();
  }

  @override
  void onClose() {
    _balanceCoordinator.stopAutoRefresh();
    super.onClose();
  }
}

/// 创建钱包后需要交给用户备份的信息。
///
/// 目前只包含助记词，底部弹窗会根据该对象切换到助记词备份步骤。
class CreatedWalletBackup {
  const CreatedWalletBackup({required this.walletId, required this.mnemonic});

  /// 新钱包 ID，用于记录助记词是否已经完成备份确认。
  final String walletId;

  /// 新钱包的助记词，用户需要离线保存。
  final String mnemonic;
}
