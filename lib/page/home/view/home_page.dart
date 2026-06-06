import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../common/theme/app_theme_extension.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../page/transfer/view/transfer_page.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/asset_valuation_service.dart';
import '../../../wallet/services/chain_balance_service.dart';
import '../../../wallet/services/wallet_crypto_service.dart';
import '../../../wallet/services/wallet_repository.dart';

class HomePage extends BaseScaffoldPage<HomeController> {
  /// 创建首页控制器，负责钱包加载、余额刷新和资产估值。
  @override
  HomeController generateController() {
    return HomeController();
  }

  /// 首页顶部标题栏，当前钱包模块只展示应用名称。
  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(title: Text(S.of(context!).appName));
  }

  /// 根据本地是否已有钱包，切换空钱包引导或钱包资产面板。
  @override
  Widget? getBody() {
    final wallet = controller.wallet;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: wallet == null
            ? [_buildEmptyWallet()]
            : [
                _buildWalletHeader(wallet),
                SizedBox(height: 16.h),
                _buildActionRow(),
                SizedBox(height: 16.h),
                _buildChainSection(wallet),
                SizedBox(height: 16.h),
                _buildPrivateKeyNotice(),
              ],
      ),
    );
  }

  /// 未创建/导入钱包时展示的引导卡片。
  Widget _buildEmptyWallet() {
    final colorScheme = Theme.of(context!).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              size: 30.w,
              color: colorScheme.primary,
            ),
          ).marginOnly(bottom: 16.h),
          Text(
            S.of(context!).walletEmptyTitle,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800),
          ).marginOnly(bottom: 8.h),
          Text(
            S.of(context!).walletEmptySubtitle,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(
                context!,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ).marginOnly(bottom: 24.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 13.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: controller.createWallet,
              icon: const Icon(Icons.add),
              label: Text(S.of(context!).createWallet),
            ),
          ).marginOnly(bottom: 10.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 13.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () => _showImportSheet(),
              icon: const Icon(Icons.file_download_outlined),
              label: Text(S.of(context!).importWallet),
            ),
          ),
        ],
      ),
    );
  }

  /// 钱包概览卡片，展示钱包名称和已计算的美元总资产估值。
  Widget _buildWalletHeader(WalletAccount wallet) {
    final colorScheme = Theme.of(context!).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 18.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16.w,
            top: -18.h,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 118.w,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wallet.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      '${WalletChain.bsc.symbol} / ${WalletChain.tron.symbol}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ).marginOnly(bottom: 24.h),
              Text(
                S.of(context!).totalAssets,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13.sp,
                ),
              ),
              Text(
                controller.totalAssetsText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool filled,
    Widget? loadingIcon,
  }) {
    final colorScheme = Theme.of(context!).colorScheme;
    final foreground = filled ? Colors.white : colorScheme.onSurface;
    return Expanded(
      child: Material(
        color: filled ? colorScheme.primary : Theme.of(context!).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: filled
                  ? null
                  : Border.all(
                      color: context!.appTheme.dividerColor!.withValues(
                        alpha: 0.6,
                      ),
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                loadingIcon ??
                    Icon(
                      icon,
                      size: 18.w,
                      color: foreground,
                    ).marginOnly(right: 7.w),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 首页快捷操作：刷新链上余额和移除当前钱包。
  Widget _buildActionRow() {
    return Row(
      children: [
        _buildActionButton(
          filled: true,
          onPressed: controller.refreshBalances,
          icon: Icons.refresh_rounded,
          loadingIcon: controller.isLoading
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ).marginOnly(right: 7.w)
              : null,
          label: S.of(context!).refreshBalance,
        ),
        SizedBox(width: 12.w),
        _buildActionButton(
          filled: false,
          onPressed: controller.removeWallet,
          icon: Icons.delete_outline_rounded,
          label: S.of(context!).removeWallet,
        ),
      ],
    );
  }

  /// 将余额列表按链拆分，分别渲染 BSC 和 TRON 资产卡片。
  Widget _buildChainSection(WalletAccount wallet) {
    final bscBalances = controller.balances
        .where((balance) => balance.chain == WalletChain.bsc)
        .toList();
    final tronBalances = controller.balances
        .where((balance) => balance.chain == WalletChain.tron)
        .toList();
    return Column(
      children: [
        _buildChainCard(
          WalletChain.bsc,
          wallet.bscAddress,
          bscBalances,
        ).marginOnly(bottom: 12.h),
        _buildChainCard(WalletChain.tron, wallet.tronAddress, tronBalances),
      ],
    );
  }

  /// 单条链的地址和资产列表。余额为空时根据加载状态显示占位文本。
  Widget _buildChainCard(
    WalletChain chain,
    String address,
    List<ChainBalance> balances,
  ) {
    final hasError = balances.any((balance) => balance.hasError);
    final chainColor = _chainColor(chain);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  chain.symbol.characters.first,
                  style: TextStyle(
                    color: chainColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chain.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context!,
                        ).colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).marginOnly(bottom: 12.h),
          ...balances.map(_buildAssetRow),
          if (balances.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context!,
                ).colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                controller.isLoading ? S.of(context!).loading : '--',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(
                    context!,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          if (hasError)
            Text(
              S.of(context!).balanceLoadFailed,
              style: TextStyle(
                color: Theme.of(context!).colorScheme.error,
                fontSize: 12.sp,
              ),
            ).marginOnly(top: 8.h),
        ],
      ),
    );
  }

  /// 单个代币余额行，右侧入口跳转到独立转账页面。
  Widget _buildAssetRow(ChainBalance balance) {
    final assetColor = _assetColor(balance.symbol);
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context!).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: context!.appTheme.dividerColor!.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: assetColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              balance.symbol.characters.first,
              style: TextStyle(
                color: assetColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ).marginOnly(right: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.symbol,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  balance.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(
                      context!,
                    ).colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 106.w),
                child: Text(
                  '${balance.amount} ${balance.symbol}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(38.w, 38.w)),
                onPressed: () => _openTransferPage(balance),
                icon: Container(
                  width: 34.w,
                  height: 34.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context!,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 20.w,
                    color: Theme.of(context!).colorScheme.primary,
                  ),
                ),
                tooltip: S.of(context!).transfer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 私钥本地存储风险提示，避免用户误导入真实资产钱包。
  Widget _buildPrivateKeyNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context!).colorScheme.error,
          ).marginOnly(right: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context!).securityNotice,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  S.of(context!).securityNoticeDetail,
                  style: TextStyle(fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Theme.of(context!).cardColor,
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(
        color: context!.appTheme.dividerColor!.withValues(alpha: 0.45),
      ),
      boxShadow: [
        BoxShadow(
          color: context!.appTheme.cardShadowColor ?? Colors.transparent,
          blurRadius: 14.r,
          offset: Offset(0, 6.h),
        ),
      ],
    );
  }

  Color _chainColor(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return const Color(0xFFF0B90B);
      case WalletChain.tron:
        return const Color(0xFFE50914);
    }
  }

  Color _assetColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'USDT':
        return const Color(0xFF26A17B);
      case 'USDC':
        return const Color(0xFF2775CA);
      case 'BTCB':
        return const Color(0xFFF7931A);
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'TRX':
        return const Color(0xFFE50914);
      default:
        return Theme.of(context!).colorScheme.primary;
    }
  }

  /// 导入私钥的底部弹窗，提交后由控制器校验并持久化钱包。
  void _showImportSheet() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 18.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context!).importPrivateKey,
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
              ).marginOnly(bottom: 12.h),
              TextField(
                controller: textController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: S.of(context!).privateKeyHint,
                  border: const OutlineInputBorder(),
                ),
              ).marginOnly(bottom: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final ok = await controller.importWallet(
                      textController.text,
                    );
                    if (ok && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Text(S.of(context!).confirmImport),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 打开转账页面；页面返回成功结果后刷新首页余额。
  Future<void> _openTransferPage(ChainBalance balance) async {
    final currentWallet = controller.wallet;
    if (currentWallet == null) return;
    final submitted = await Get.toNamed(
      RouteTable.transfer,
      arguments: TransferPageArguments(
        privateKeyHex: currentWallet.privateKeyHex,
        asset: balance,
      ),
    );
    if (submitted == true) {
      controller.refreshBalances();
    }
  }
}

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
