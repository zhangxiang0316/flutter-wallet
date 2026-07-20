import 'dart:async';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/password_cache_service.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/asset_valuation_service.dart';
import '../../../wallet/services/chain_balance_cache.dart';
import '../../../wallet/services/chain_balance_service.dart';
import '../../../wallet/services/config/wallet_asset_visibility_service.dart';
import '../../../wallet/services/config/wallet_backup_status_service.dart';
import '../../../wallet/services/config/wallet_chain_config_service.dart';
import '../../../wallet/services/crypto/wallet_crypto_service.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/crypto/wallet_secret_store.dart';
import 'home_controller_utils.dart';

part 'home_controller_valuation.dart';
part 'home_controller_balance.dart';

/// 首页控制器。
///
/// 负责钱包生命周期、余额刷新、资产可见性过滤、USD 估值、旧数据安全迁移和
/// 多钱包切换。首页 Widget 只消费这里整理好的状态，不直接访问钱包服务。
class HomeController extends BaseController {
  HomeController({
    WalletRepository? repository,
    WalletCryptoService? cryptoService,
    ChainBalanceService? balanceService,
    AssetValuationService? valuationService,
    WalletAssetVisibilityService? assetVisibilityService,
    WalletBackupStatusService? backupStatusService,
    WalletChainConfigService? chainConfigService,
    ChainBalanceCache? balanceCache,
  }) : _repository = repository ?? WalletRepository(),
       _cryptoService = cryptoService ?? WalletCryptoService(),
       _balanceService = balanceService ?? ChainBalanceService(),
       _valuationService = valuationService ?? AssetValuationService(),
       _assetVisibilityService =
           assetVisibilityService ?? WalletAssetVisibilityService(),
       _backupStatusService =
           backupStatusService ?? WalletBackupStatusService(),
       _chainConfigService = chainConfigService ?? WalletChainConfigService(),
       _balanceCache = balanceCache ?? ChainBalanceCache();

  final WalletRepository _repository;
  final WalletCryptoService _cryptoService;
  final ChainBalanceService _balanceService;
  final AssetValuationService _valuationService;
  final WalletAssetVisibilityService _assetVisibilityService;
  final WalletBackupStatusService _backupStatusService;
  final WalletChainConfigService _chainConfigService;
  final ChainBalanceCache _balanceCache;

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

  /// 当前被用户隐藏的资产 key 集合。
  ///
  /// key 的生成规则由 [WalletAssetVisibilityService] 维护，控制器只负责读取和传递。
  Set<String> hiddenAssetKeys = {};

  /// 已格式化的总资产估值文本。价格源不可用时显示 `--`。
  String totalAssetsText = '--';

  /// 非稳定币按当前价格换算成稳定币后的展示文本。
  final Map<String, String> assetStableValueTexts = {};

  /// 每条链按当前价格汇总后的 USD 估值文本。
  final Map<String, String> chainUsdValueTexts = {};

  /// ✅ 缓存的价格数据，用于优化价格计算
  final Map<String, Decimal> _cachedPrices = {};

  /// 防止重复发起余额刷新，并驱动刷新按钮和链卡片 loading 状态。
  bool isLoading = false;

  /// 旧版本钱包仍含明文私钥时为 true，需要先设置密码完成迁移。
  bool needsSecretMigration = false;

  /// 是否正在执行旧钱包明文私钥加密迁移。
  bool isMigratingSecrets = false;

  /// 旧钱包缺少 Solana 地址时为 true，需要输入钱包密码补派生地址。
  bool needsSolanaAddressUpgrade = false;

  /// 是否正在为旧钱包补全 Solana 地址。
  bool isUpgradingSolanaAddresses = false;

  /// 当前已展开的链。默认空集合，首页只展示链信息。
  final Set<String> expandedChainIds = {};

  /// 是否隐藏 0 余额资产。
  bool hideZeroBalances = false;

  Timer? _balanceRefreshTimer;

  /// 余额请求版本号。
  ///
  /// 切换钱包或重新发起刷新时递增，用于丢弃旧异步请求返回的过期结果。
  int _balanceRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    loadWallet();
  }

  /// 启动时读取本地钱包；如果存在钱包，立即拉取当前钱包的链上余额。
  Future<void> loadWallet() async {
    hiddenAssetKeys = await _assetVisibilityService.loadHiddenAssetKeys();
    chains = await _chainConfigService.loadEnabledChains();
    wallets = await _repository.loadWallets();
    wallet = await _repository.loadCurrentWallet();
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
      wallet,
    );
    update();
    if (wallet != null) {
      _startBalanceRefreshTimer();
      refreshBalances();
    }
  }

  /// 同步钱包元数据和资产显示配置。
  ///
  /// 从设置页或钱包详情页返回首页时调用，确保钱包名称、隐藏资产和总资产估值
  /// 都用最新本地配置重新渲染。
  Future<void> syncWalletMetadata() async {
    hiddenAssetKeys = await _assetVisibilityService.loadHiddenAssetKeys();
    chains = await _chainConfigService.loadEnabledChains();
    _applyAssetVisibility();
    final currentWalletId = wallet?.id;
    wallets = await _repository.loadWallets();
    wallet = currentWalletId == null
        ? await _repository.loadCurrentWallet()
        : wallets.firstWhere(
            (item) => item.id == currentWalletId,
            orElse: () => wallet!,
          );
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
      wallet,
    );
    _refreshTotalAssetsFromCachedPrices();
    _refreshAssetStableValueTexts(_valuationService.cachedUsdPrices);
    _refreshChainUsdValueTexts(_valuationService.cachedUsdPrices);
    update();
  }

  /// 生成助记词并创建钱包，保存后刷新链上余额。
  Future<CreatedWalletBackup?> createWallet(String password) async {
    final mnemonic = _cryptoService.generateMnemonic();
    final keyPair = _cryptoService.importMnemonic(mnemonic);
    final nextWallet = WalletAccount(
      id: HomeControllerUtils.createWalletId(keyPair.bscAddress),
      name: 'Wallet ${wallets.length + 1}',
      bscAddress: keyPair.bscAddress,
      tronAddress: keyPair.tronAddress,
      solanaAddress: keyPair.solanaAddress,
      createdAt: DateTime.now(),
    );
    await _repository.saveWalletSecret(
      walletId: nextWallet.id,
      password: password,
      privateKeyHex: keyPair.privateKeyHex,
      mnemonic: keyPair.mnemonic,
    );
    await _saveAndSelectWallet(nextWallet);
    Toast.show(S.current.walletCreated);
    return CreatedWalletBackup(walletId: nextWallet.id, mnemonic: mnemonic);
  }

  /// 导入用户输入的私钥，派生 EVM/TRON 地址并保存到本地。
  Future<bool> importPrivateKeyWallet(
    String privateKey,
    String password,
  ) async {
    try {
      final keyPair = _cryptoService.importPrivateKey(privateKey);
      return _saveImportedWallet(keyPair, password);
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
      final keyPair = _cryptoService.importMnemonic(mnemonic);
      return _saveImportedWallet(keyPair, password);
    } catch (_) {
      Toast.show(S.current.invalidMnemonic);
      return false;
    }
  }

  /// 将旧版本明文私钥迁移为本地加密存储。
  ///
  /// 迁移成功后会顺带为缺少 Solana 地址的旧钱包补齐地址，避免用户还要再走
  /// 一次解锁流程。
  Future<bool> migrateLegacySecrets(String password) async {
    if (isMigratingSecrets) return false;
    try {
      isMigratingSecrets = true;
      update();
      final legacyWalletIds = wallets
          .where((wallet) => wallet.needsSecretMigration)
          .map((wallet) => wallet.id)
          .toSet();
      await _repository.migrateLegacyPlainSecrets(password);
      await _upgradeMissingSolanaAddresses(
        password,
        walletIds: legacyWalletIds,
      );
      needsSecretMigration = false;
      needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
        wallet,
      );
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

  /// 为缺少 Solana 地址的旧钱包补派生地址。
  ///
  /// 该流程需要用户输入钱包密码以读取加密私钥，完成后会刷新余额。
  Future<bool> upgradeMissingSolanaAddresses(String password) async {
    if (isUpgradingSolanaAddresses) return false;
    try {
      isUpgradingSolanaAddresses = true;
      update();
      await _upgradeMissingSolanaAddresses(password);
      Toast.show(S.current.walletSolanaAddressUpgraded);
      update();
      refreshBalances();
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
      isUpgradingSolanaAddresses = false;
      update();
    }
  }

  /// 切换当前钱包。
  ///
  /// 切换后会清空旧余额、重启 30 秒刷新定时器，并立即请求新钱包余额。
  Future<void> switchWallet(WalletAccount nextWallet) async {
    if (wallet?.id == nextWallet.id) return;
    await _repository.setCurrentWalletId(nextWallet.id);
    wallet = nextWallet;
    needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
      nextWallet,
    );
    _resetWalletState();
    update();
    _startBalanceRefreshTimer();
    refreshBalances();
  }

  /// 删除当前钱包和页面状态，不触发任何链上操作。
  Future<void> removeWallet([WalletAccount? targetWallet]) async {
    final walletToRemove = targetWallet ?? wallet;
    if (walletToRemove == null) return;
    final removedCurrentWallet = wallet?.id == walletToRemove.id;
    await _repository.removeWallet(walletToRemove.id);
    PasswordCacheService.clearCache(walletId: walletToRemove.id);
    await _backupStatusService.clearMnemonicBackedUp(walletToRemove.id);
    wallets = await _repository.loadWallets();
    wallet = await _repository.loadCurrentWallet();
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
      wallet,
    );
    if (removedCurrentWallet) {
      _resetWalletState();
      update();
      if (wallet == null) {
        _stopBalanceRefreshTimer();
      } else {
        _startBalanceRefreshTimer();
        refreshBalances();
      }
    } else {
      update();
    }
    Toast.show(S.current.walletRemoved);
  }

  /// 保存钱包并把它设为当前钱包。
  ///
  /// 创建和导入流程共用该方法，确保钱包列表、当前钱包和余额刷新状态一致。
  Future<void> _saveAndSelectWallet(WalletAccount nextWallet) async {
    await _repository.saveWallet(nextWallet);
    wallets = await _repository.loadWallets();
    wallet = wallets.firstWhere(
      (item) => item.id == nextWallet.id,
      orElse: () => nextWallet,
    );
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
      wallet,
    );
    _resetWalletState();
    update();
    _startBalanceRefreshTimer();
    refreshBalances();
  }

  /// 保存导入的钱包。
  ///
  /// 如果同一 EVM 地址已经存在，则沿用原钱包名称；否则使用递增默认名称。
  Future<bool> _saveImportedWallet(
    WalletKeyPair keyPair,
    String password,
  ) async {
    final existingIndex = wallets.indexWhere(
      (wallet) =>
          wallet.bscAddress.toLowerCase() == keyPair.bscAddress.toLowerCase(),
    );
    final nextWallet = WalletAccount(
      id: HomeControllerUtils.createWalletId(keyPair.bscAddress),
      name: existingIndex >= 0
          ? wallets[existingIndex].name
          : 'Wallet ${wallets.length + 1}',
      bscAddress: keyPair.bscAddress,
      tronAddress: keyPair.tronAddress,
      solanaAddress: keyPair.solanaAddress,
      createdAt: DateTime.now(),
    );
    await _repository.saveWalletSecret(
      walletId: nextWallet.id,
      password: password,
      privateKeyHex: keyPair.privateKeyHex,
      mnemonic: keyPair.mnemonic,
    );
    await _saveAndSelectWallet(nextWallet);
    Toast.show(S.current.walletImported);
    return true;
  }

  /// 遍历本地钱包并补全缺失的 Solana 地址。
  ///
  /// [walletIds] 不为空时只处理指定钱包集合；为空时默认只处理当前钱包。
  Future<void> _upgradeMissingSolanaAddresses(
    String password, {
    Set<String>? walletIds,
  }) async {
    final currentWalletId =
        wallet?.id ?? await _repository.loadCurrentWalletId();
    final nextWallets = <WalletAccount>[];
    for (final item in await _repository.loadWallets()) {
      final shouldUpgrade =
          item.solanaAddress.trim().isEmpty &&
          (walletIds?.contains(item.id) ?? item.id == currentWalletId);
      if (!shouldUpgrade) {
        nextWallets.add(item);
        continue;
      }

      final privateKeyHex = item.needsSecretMigration
          ? item.privateKeyHex
          : await _repository.readWalletPrivateKey(
              walletId: item.id,
              password: password,
            );
      final keyPair = _cryptoService.importPrivateKey(privateKeyHex);
      nextWallets.add(item.copyWith(solanaAddress: keyPair.solanaAddress));
    }

    await _repository.saveWallets(
      nextWallets,
      currentWalletId: currentWalletId,
    );
    wallets = await _repository.loadWallets();
    wallet = await _repository.loadCurrentWallet();
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = HomeControllerUtils.needsSolanaAddressUpgrade(
      wallet,
    );
  }

  /// 启动 60 秒余额定时刷新。
  ///
  /// 每次进入或切换钱包都会先停止旧定时器，避免多个定时器并发刷新。
  void _startBalanceRefreshTimer() {
    _stopBalanceRefreshTimer();
    _balanceRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refreshBalances();
    });
  }

  /// 停止余额定时刷新。
  void _stopBalanceRefreshTimer() {
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = null;
  }

  /// 页面可见时恢复定时刷新。
  @override
  void onPageVisible() {
    super.onPageVisible();
    // 如果有钱包且定时器未运行，启动定时器
    if (wallet != null && _balanceRefreshTimer == null) {
      _startBalanceRefreshTimer();
      // 页面可见时立即刷新一次余额，确保数据最新
      refreshBalances();
    } else if (wallet != null && _balanceRefreshTimer != null) {
      // 如果定时器已在运行（从其他页面返回），也立即刷新一次
      refreshBalances();
    }
  }

  /// 页面不可见时暂停定时刷新，节省资源。
  @override
  void onPageInVisible() {
    super.onPageInVisible();
    // 页面不可见时停止定时器
    _stopBalanceRefreshTimer();
  }

  @override
  void onClose() {
    _stopBalanceRefreshTimer();
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
