import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../page/transfer/controller/transfer_controller.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../home/controller/home_controller.dart';
import 'widgets/add_wallet_sheet.dart';
import 'widgets/chain_section.dart';
import 'widgets/empty_wallet_card.dart';
import 'widgets/home_background.dart';
import 'widgets/import_wallet_sheet.dart';
import 'widgets/password_setup_sheet.dart';
import 'widgets/password_unlock_sheet.dart';
import 'widgets/private_key_notice.dart';
import 'widgets/wallet_overview_card.dart';

@GetXRoutePage('/home')
// ignore: use_key_in_widget_constructors, must_be_immutable
class HomePage extends BaseScaffoldPage<HomeController> {
  /// 创建首页控制器，负责钱包加载、余额刷新和资产估值。
  @override
  HomeController generateController() {
    return HomeController();
  }

  /// 首页顶部标题栏，当前钱包模块只展示应用名称。
  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
      centerTitle: true,
      elevation: 0,
      leadingWidth: 52.w,
      titleSpacing: 0,
      toolbarHeight: 50.h,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: EdgeInsets.only(left: 12.w),
        child: Center(
          child: Semantics(
            button: controller.wallet != null,
            label: S.of(context!).walletDetails,
            child: InkWell(
              onTap: controller.wallet == null ? null : _openWalletDetailPage,
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.16),
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colorScheme.primary,
                  size: 17.w,
                ),
              ),
            ),
          ),
        ),
      ),
      title: Text(
        S.of(context!).appName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        Semantics(
          button: true,
          label: S.of(context!).settings,
          child: IconButton(
            tooltip: S.of(context!).settings,
            icon: const Icon(Icons.tune_rounded),
            color: colorScheme.onSurface.withValues(alpha: 0.82),
            iconSize: 20.w,
            onPressed: () async {
              await Get.toNamed(RouteTable.setting);
              await controller.syncWalletMetadata();
              controller.refreshBalances();
            },
          ),
        ).marginOnly(right: 6.w),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context!).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context!).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  /// 根据本地是否已有钱包，切换空钱包引导或钱包资产面板。
  @override
  Widget? getBody() {
    final wallet = controller.wallet;
    _scheduleLegacyMigrationSheet();
    _scheduleSolanaAddressUpgradeSheet();
    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: wallet == null
            ? [
                EmptyWalletCard(
                  onCreateWallet: _showCreateWalletSheet,
                  onImportWallet: _showImportSheet,
                ),
              ]
            : [
                WalletOverviewCard(
                  wallet: wallet,
                  wallets: controller.wallets,
                  totalAssetsText: controller.totalAssetsText,
                  onWalletSelected: controller.switchWallet,
                  onWalletRemoved: controller.removeWallet,
                  onAddWallet: _showAddWalletSheet,
                  onReceivePressed: _openReceivePage,
                ),
                SizedBox(height: 16.h),
                ChainSection(
                  wallet: wallet,
                  balances: controller.visibleBalances,
                  isLoading: controller.isLoading,
                  stableValueTextFor: controller.stableValueTextFor,
                  chainUsdValueTextFor: controller.chainUsdValueTextFor,
                  isChainExpanded: controller.isChainExpanded,
                  onChainToggle: controller.toggleChainExpanded,
                  onTransferPressed: _openTransferPage,
                ),
                SizedBox(height: 16.h),
                const PrivateKeyNotice(),
              ],
      ),
    );
    if (wallet == null) {
      return HomeBackground(child: content);
    }
    return RefreshIndicator(
      backgroundColor: Theme.of(context!).cardColor,
      color: Theme.of(context!).colorScheme.primary,
      displacement: 20.h,
      edgeOffset: 2.h,
      onRefresh: controller.refreshBalances,
      child: HomeBackground(child: content),
    );
  }

  /// 导入私钥的底部弹窗，提交后由控制器校验并持久化钱包。
  void _showImportSheet() {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ImportWalletSheet(
        onMnemonicSubmit: controller.importMnemonicWallet,
        onPrivateKeySubmit: controller.importPrivateKeyWallet,
        validatePassword: _validatePassword,
      ),
    );
  }

  /// 打开创建钱包密码设置流程。
  void _showCreateWalletSheet() {
    _showPasswordSetupSheet(
      title: S.of(context!).createWallet,
      submitLabel: S.of(context!).createWallet,
      onSubmit: controller.createWallet,
    );
  }

  /// 打开添加钱包选择面板。
  void _showAddWalletSheet() {
    showModalBottomSheet(
      context: context!,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddWalletSheet(
        onCreateWallet: _showCreateWalletSheet,
        onImportWallet: _showImportSheet,
      ),
    );
  }

  /// 打开密码设置面板。
  ///
  /// 创建钱包和旧钱包安全迁移共用该方法，通过 [onSubmit] 区分实际业务。
  void _showPasswordSetupSheet({
    required String title,
    required String submitLabel,
    required Future<Object?> Function(String password) onSubmit,
    bool isDismissible = true,
  }) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PasswordSetupSheet(
        title: title,
        submitLabel: submitLabel,
        isDismissible: isDismissible,
        onSubmit: onSubmit,
        validatePassword: _validatePassword,
      ),
    );
  }

  /// 在旧钱包仍含明文私钥时，安排安全迁移弹窗。
  ///
  /// 弹窗在当前帧绘制完成后出现，避免在 build 过程中直接打开 BottomSheet。
  void _scheduleLegacyMigrationSheet() {
    if (!controller.needsSecretMigration || _legacyMigrationSheetVisible) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.needsSecretMigration ||
          _legacyMigrationSheetVisible ||
          context == null) {
        return;
      }
      _legacyMigrationSheetVisible = true;
      _showPasswordSetupSheet(
        title: S.of(context!).walletSecurityUpgrade,
        submitLabel: S.of(context!).encryptWallet,
        isDismissible: false,
        onSubmit: controller.migrateLegacySecrets,
      );
    });
  }

  /// 在旧钱包缺少 Solana 地址时，安排地址升级弹窗。
  void _scheduleSolanaAddressUpgradeSheet() {
    if (controller.needsSecretMigration ||
        !controller.needsSolanaAddressUpgrade ||
        _solanaAddressUpgradeSheetVisible) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.needsSecretMigration ||
          !controller.needsSolanaAddressUpgrade ||
          _solanaAddressUpgradeSheetVisible ||
          context == null) {
        return;
      }
      _solanaAddressUpgradeSheetVisible = true;
      _showPasswordUnlockSheet(
        title: S.of(context!).walletSolanaAddressUpgrade,
        detail: S.of(context!).walletSolanaAddressUpgradeDetail,
        submitLabel: S.of(context!).walletSolanaAddressUpgradeAction,
        onSubmit: controller.upgradeMissingSolanaAddresses,
      );
    });
  }

  /// 打开钱包密码解锁面板。
  ///
  /// 当前用于补全 Solana 地址等需要读取加密私钥的维护流程。
  void _showPasswordUnlockSheet({
    required String title,
    required String detail,
    required String submitLabel,
    required Future<bool> Function(String password) onSubmit,
  }) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PasswordUnlockSheet(
        title: title,
        detail: detail,
        submitLabel: submitLabel,
        onSubmit: onSubmit,
      ),
    ).whenComplete(() => _solanaAddressUpgradeSheetVisible = false);
  }

  /// 校验创建/导入钱包时设置的本地密码。
  bool _validatePassword(String password, String confirmPassword) {
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return false;
    }
    if (password.length < 6) {
      Toast.show(S.current.walletPasswordTooShort);
      return false;
    }
    if (password != confirmPassword) {
      Toast.show(S.current.walletPasswordMismatch);
      return false;
    }
    return true;
  }

  /// 打开转账页面；页面返回成功结果后刷新首页余额。
  Future<void> _openTransferPage(ChainBalance balance) async {
    final currentWallet = controller.wallet;
    if (currentWallet == null) return;
    final submitted = await Get.toNamed(
      RouteTable.transfer,
      arguments: TransferPageArguments(
        walletId: currentWallet.id,
        asset: balance,
        assets: controller.visibleBalances,
      ),
    );
    if (submitted == true) {
      controller.refreshBalances();
    }
  }

  /// 打开钱包详情页面。
  ///
  /// 返回后同步钱包名称等本地元数据。
  Future<void> _openWalletDetailPage() async {
    final currentWallet = controller.wallet;
    if (currentWallet == null) return;
    await Get.toNamed(RouteTable.walletDetail, arguments: currentWallet.id);
    await controller.syncWalletMetadata();
  }

  /// 打开收款页面，收款页只需要当前钱包的各链地址。
  Future<void> _openReceivePage() async {
    final currentWallet = controller.wallet;
    if (currentWallet == null) return;
    await Get.toNamed(RouteTable.receive, arguments: currentWallet);
  }

  /// 旧钱包安全迁移弹窗是否正在显示。
  bool _legacyMigrationSheetVisible = false;

  /// Solana 地址升级弹窗是否正在显示。
  bool _solanaAddressUpgradeSheetVisible = false;
}
