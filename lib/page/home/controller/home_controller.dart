import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_account.dart';
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

  /// BSC 和 TRON 的资产余额列表，由 [ChainBalanceService] 从链上查询。
  List<ChainBalance> balances = [];

  /// 已格式化的总资产估值文本。价格源不可用时显示 `--`。
  String totalAssetsText = '--';

  /// 防止重复发起余额刷新，并驱动刷新按钮和链卡片 loading 状态。
  bool isLoading = false;

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
    refreshBalances();
  }

  /// 导入用户输入的私钥，派生 BSC/TRON 地址并保存到本地。
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
      refreshBalances();
      return true;
    } catch (_) {
      Toast.show(S.current.invalidPrivateKey);
      return false;
    }
  }

  /// 查询两条链的资产余额。余额先更新到 UI，再异步刷新总资产估值。
  Future<void> refreshBalances() async {
    final currentWallet = wallet;
    if (currentWallet == null || isLoading) return;
    isLoading = true;
    update();
    balances = await _balanceService.loadBalances(
      bscAddress: currentWallet.bscAddress,
      tronAddress: currentWallet.tronAddress,
    );
    isLoading = false;
    update();
    // 估值依赖外部价格接口，放在余额渲染后执行，避免资产列表被价格接口阻塞。
    await refreshTotalAssets();
  }

  /// 根据当前余额计算美元估值，并更新首页头部展示。
  Future<void> refreshTotalAssets() async {
    final totalValue = await _valuationService.loadTotalUsdValue(balances);
    totalAssetsText = _valuationService.formatUsdValue(totalValue);
    update();
  }

  /// 删除本地钱包和页面状态，不触发任何链上操作。
  Future<void> removeWallet() async {
    await _repository.clearWallet();
    wallet = null;
    balances = [];
    totalAssetsText = '--';
    update();
    Toast.show(S.current.walletRemoved);
  }
}
