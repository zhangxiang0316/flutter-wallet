import 'dart:async';

import 'package:decimal/decimal.dart';

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
import '../../../wallet/services/wallet_secret_store.dart';

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

  /// 本地保存的钱包列表。
  List<WalletAccount> wallets = [];

  /// 当前选中的钱包；为空时首页展示创建/导入入口。
  WalletAccount? wallet;

  /// 多链资产余额列表，由 [ChainBalanceService] 从链上查询。
  List<ChainBalance> balances = [];

  /// 已格式化的总资产估值文本。价格源不可用时显示 `--`。
  String totalAssetsText = '--';

  /// 非稳定币按当前价格换算成稳定币后的展示文本。
  final Map<String, String> assetStableValueTexts = {};

  /// 每条链按当前价格汇总后的 USD 估值文本。
  final Map<String, String> chainUsdValueTexts = {};

  /// 防止重复发起余额刷新，并驱动刷新按钮和链卡片 loading 状态。
  bool isLoading = false;

  /// 旧版本钱包仍含明文私钥时为 true，需要先设置密码完成迁移。
  bool needsSecretMigration = false;

  bool isMigratingSecrets = false;

  /// 旧钱包缺少 Solana 地址时为 true，需要输入钱包密码补派生地址。
  bool needsSolanaAddressUpgrade = false;

  bool isUpgradingSolanaAddresses = false;

  /// 当前已展开的链。默认空集合，首页只展示链信息。
  final Set<String> expandedChainIds = {};

  Timer? _balanceRefreshTimer;
  int _balanceRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    loadWallet();
  }

  /// 启动时读取本地钱包；如果存在钱包，立即拉取当前钱包的链上余额。
  Future<void> loadWallet() async {
    wallets = await _repository.loadWallets();
    wallet = await _repository.loadCurrentWallet();
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = _needsSolanaAddressUpgrade(wallet);
    update();
    if (wallet != null) {
      _startBalanceRefreshTimer();
      refreshBalances();
    }
  }

  /// 生成助记词并创建钱包，保存后刷新链上余额。
  Future<CreatedWalletBackup?> createWallet(String password) async {
    final mnemonic = _cryptoService.generateMnemonic();
    final keyPair = _cryptoService.importMnemonic(mnemonic);
    final nextWallet = WalletAccount(
      id: _createWalletId(keyPair.bscAddress),
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
    return CreatedWalletBackup(mnemonic: mnemonic);
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

  Future<bool> importMnemonicWallet(String mnemonic, String password) async {
    try {
      final keyPair = _cryptoService.importMnemonic(mnemonic);
      return _saveImportedWallet(keyPair, password);
    } catch (_) {
      Toast.show(S.current.invalidMnemonic);
      return false;
    }
  }

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
      needsSolanaAddressUpgrade = _needsSolanaAddressUpgrade(wallet);
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

  /// 查询多条链的资产余额。余额先更新到 UI，再异步刷新总资产估值。
  Future<void> refreshBalances() async {
    final currentWallet = wallet;
    if (currentWallet == null || isLoading) return;
    final requestId = ++_balanceRequestId;
    isLoading = true;
    update();

    try {
      final nextBalances = await _balanceService.loadBalances(
        bscAddress: currentWallet.bscAddress,
        tronAddress: currentWallet.tronAddress,
        solanaAddress: currentWallet.solanaAddress,
      );
      if (requestId != _balanceRequestId || wallet?.id != currentWallet.id) {
        return;
      }
      balances = nextBalances;
      _refreshTotalAssetsFromCachedPrices();
      _refreshAssetStableValueTexts(_valuationService.cachedUsdPrices);
      _refreshChainUsdValueTexts(_valuationService.cachedUsdPrices);
      isLoading = false;
      update();

      final latestPrices = await _valuationService
          .loadUsdPrices(balances)
          .catchError((_) => _valuationService.cachedUsdPrices);
      if (requestId != _balanceRequestId || wallet?.id != currentWallet.id) {
        return;
      }
      final totalValue = _valuationService.calculateTotalUsdValue(
        balances,
        prices: latestPrices,
      );
      totalAssetsText = _valuationService.formatUsdValue(totalValue);
      _refreshAssetStableValueTexts(latestPrices);
      _refreshChainUsdValueTexts(latestPrices);
      update();
    } catch (_) {
      if (requestId != _balanceRequestId || wallet?.id != currentWallet.id) {
        return;
      }
      Toast.show(S.current.balanceLoadFailed);
    } finally {
      if (requestId == _balanceRequestId && wallet?.id == currentWallet.id) {
        isLoading = false;
        update();
      }
    }
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

  String? stableValueTextFor(ChainBalance balance) {
    return assetStableValueTexts[_assetStableValueKey(balance)];
  }

  String chainUsdValueTextFor(WalletChain chain) {
    return chainUsdValueTexts[chain.id] ?? '--';
  }

  void _refreshAssetStableValueTexts(Map<String, Decimal> prices) {
    assetStableValueTexts.clear();
    for (final balance in balances) {
      final valueText = _valuationService.formatNonStableUsdValue(
        balance,
        prices: prices,
      );
      if (valueText != null) {
        assetStableValueTexts[_assetStableValueKey(balance)] = valueText;
      }
    }
  }

  void _refreshChainUsdValueTexts(Map<String, Decimal> prices) {
    chainUsdValueTexts.clear();
    for (final chain in WalletChain.values) {
      final chainBalances = balances
          .where((balance) => balance.chain == chain)
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

  String _assetStableValueKey(ChainBalance balance) {
    return [
      balance.chain.id,
      balance.contractAddress ?? 'native',
      balance.symbol,
    ].join(':');
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

  Future<void> switchWallet(WalletAccount nextWallet) async {
    if (wallet?.id == nextWallet.id) return;
    await _repository.setCurrentWalletId(nextWallet.id);
    wallet = nextWallet;
    needsSolanaAddressUpgrade = _needsSolanaAddressUpgrade(nextWallet);
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
    wallets = await _repository.loadWallets();
    wallet = await _repository.loadCurrentWallet();
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = _needsSolanaAddressUpgrade(wallet);
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

  Future<void> _saveAndSelectWallet(WalletAccount nextWallet) async {
    await _repository.saveWallet(nextWallet);
    wallets = await _repository.loadWallets();
    wallet = wallets.firstWhere(
      (item) => item.id == nextWallet.id,
      orElse: () => nextWallet,
    );
    needsSecretMigration = wallets.any((wallet) => wallet.needsSecretMigration);
    needsSolanaAddressUpgrade = _needsSolanaAddressUpgrade(wallet);
    _resetWalletState();
    update();
    _startBalanceRefreshTimer();
    refreshBalances();
  }

  Future<bool> _saveImportedWallet(
    WalletKeyPair keyPair,
    String password,
  ) async {
    final existingIndex = wallets.indexWhere(
      (wallet) =>
          wallet.bscAddress.toLowerCase() == keyPair.bscAddress.toLowerCase(),
    );
    final nextWallet = WalletAccount(
      id: _createWalletId(keyPair.bscAddress),
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

  void _resetWalletState() {
    _balanceRequestId++;
    balances = [];
    assetStableValueTexts.clear();
    chainUsdValueTexts.clear();
    expandedChainIds.clear();
    totalAssetsText = '--';
    isLoading = false;
  }

  String _createWalletId(String evmAddress) {
    return evmAddress.toLowerCase();
  }

  bool _needsSolanaAddressUpgrade(WalletAccount? wallet) {
    return wallet != null &&
        wallet.solanaAddress.trim().isEmpty &&
        !wallet.needsSecretMigration;
  }

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
    needsSolanaAddressUpgrade = _needsSolanaAddressUpgrade(wallet);
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

class CreatedWalletBackup {
  const CreatedWalletBackup({required this.mnemonic});

  final String mnemonic;
}
