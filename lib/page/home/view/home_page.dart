import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../common/theme/app_theme_extension.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../page/transfer/controller/transfer_controller.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../home/controller/home_controller.dart';
import 'widgets/chain_section.dart';
import 'widgets/empty_wallet_card.dart';
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
      return _HomeBackground(child: content);
    }
    return RefreshIndicator(
      backgroundColor: Theme.of(context!).cardColor,
      color: Theme.of(context!).colorScheme.primary,
      displacement: 20.h,
      edgeOffset: 2.h,
      onRefresh: controller.refreshBalances,
      child: _HomeBackground(child: content),
    );
  }

  /// 导入私钥的底部弹窗，提交后由控制器校验并持久化钱包。
  void _showImportSheet() {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ImportWalletSheet(
        onMnemonicSubmit: controller.importMnemonicWallet,
        onPrivateKeySubmit: controller.importPrivateKeyWallet,
        validatePassword: _validatePassword,
      ),
    );
  }

  void _showCreateWalletSheet() {
    _showPasswordSetupSheet(
      title: S.of(context!).createWallet,
      submitLabel: S.of(context!).createWallet,
      onSubmit: controller.createWallet,
    );
  }

  void _showAddWalletSheet() {
    showModalBottomSheet(
      context: context!,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _VantSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VantSheetTitle(title: S.of(context!).addWallet),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: _vantFilledButtonStyle(sheetContext),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showCreateWalletSheet();
                    });
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(S.of(context!).createWallet),
                ),
              ).marginOnly(bottom: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: _vantOutlinedButtonStyle(sheetContext),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showImportSheet();
                    });
                  },
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(S.of(context!).importWallet),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
      builder: (sheetContext) => _PasswordSetupSheet(
        title: title,
        submitLabel: submitLabel,
        isDismissible: isDismissible,
        onSubmit: onSubmit,
        validatePassword: _validatePassword,
      ),
    );
  }

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
      builder: (sheetContext) => _PasswordUnlockSheet(
        title: title,
        detail: detail,
        submitLabel: submitLabel,
        onSubmit: onSubmit,
      ),
    ).whenComplete(() => _solanaAddressUpgradeSheetVisible = false);
  }

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
      ),
    );
    if (submitted == true) {
      controller.refreshBalances();
    }
  }

  Future<void> _openWalletDetailPage() async {
    final currentWallet = controller.wallet;
    if (currentWallet == null) return;
    await Get.toNamed(RouteTable.walletDetail, arguments: currentWallet.id);
    await controller.syncWalletMetadata();
  }

  bool _legacyMigrationSheetVisible = false;
  bool _solanaAddressUpgradeSheetVisible = false;
}

class _HomeBackground extends StatelessWidget {
  const _HomeBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: child,
    );
  }
}

class _VantSheet extends StatelessWidget {
  const _VantSheet({
    required this.child,
    this.bottomInset = 0,
    this.showHandle = true,
  });

  final Widget child;
  final double bottomInset;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18.r,
              offset: Offset(0, -6.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            showHandle ? 8.h : 18.h,
            16.w,
            bottomInset + 18.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ).marginOnly(bottom: 12.h),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _VantSheetTitle extends StatelessWidget {
  const _VantSheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
    ).marginOnly(bottom: 14.h);
  }
}

class _ImportWalletSheet extends StatefulWidget {
  const _ImportWalletSheet({
    required this.onMnemonicSubmit,
    required this.onPrivateKeySubmit,
    required this.validatePassword,
  });

  final Future<bool> Function(String mnemonic, String password)
  onMnemonicSubmit;
  final Future<bool> Function(String privateKey, String password)
  onPrivateKeySubmit;
  final bool Function(String password, String confirmPassword) validatePassword;

  @override
  State<_ImportWalletSheet> createState() => _ImportWalletSheetState();
}

class _ImportWalletSheetState extends State<_ImportWalletSheet> {
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _useMnemonic = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _secretController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _VantSheet(
      bottomInset: MediaQuery.of(context).viewInsets.bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VantSheetTitle(title: S.of(context).importWallet),
          _VantSegmentedControl(
            leftLabel: S.of(context).importMnemonic,
            rightLabel: S.of(context).importPrivateKey,
            leftSelected: _useMnemonic,
            onChanged: (value) {
              setState(() {
                _useMnemonic = value;
                _secretController.clear();
              });
            },
          ).marginOnly(bottom: 14.h),
          TextField(
            controller: _secretController,
            minLines: _useMnemonic ? 3 : 2,
            maxLines: _useMnemonic ? 5 : 4,
            decoration: _vantInputDecoration(
              context,
              label: _useMnemonic
                  ? S.of(context).mnemonic
                  : S.of(context).importPrivateKey,
              hintText: _useMnemonic
                  ? S.of(context).mnemonicHint
                  : S.of(context).privateKeyHint,
              prefixIcon: _useMnemonic
                  ? Icons.password_rounded
                  : Icons.key_rounded,
            ),
          ).marginOnly(bottom: 14.h),
          _PasswordTextField(
            controller: _passwordController,
            label: S.of(context).walletPassword,
            hint: S.of(context).walletPasswordHint,
          ).marginOnly(bottom: 12.h),
          _PasswordTextField(
            controller: _confirmPasswordController,
            label: S.of(context).confirmWalletPassword,
          ).marginOnly(bottom: 14.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: _vantFilledButtonStyle(context),
              onPressed: _isSubmitting ? null : _submit,
              child: Text(S.of(context).confirmImport),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (!widget.validatePassword(
      password,
      _confirmPasswordController.text.trim(),
    )) {
      return;
    }

    setState(() => _isSubmitting = true);
    final ok = _useMnemonic
        ? await widget.onMnemonicSubmit(_secretController.text, password)
        : await widget.onPrivateKeySubmit(_secretController.text, password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}

class _PasswordSetupSheet extends StatefulWidget {
  const _PasswordSetupSheet({
    required this.title,
    required this.submitLabel,
    required this.isDismissible,
    required this.onSubmit,
    required this.validatePassword,
  });

  final String title;
  final String submitLabel;
  final bool isDismissible;
  final Future<Object?> Function(String password) onSubmit;
  final bool Function(String password, String confirmPassword) validatePassword;

  @override
  State<_PasswordSetupSheet> createState() => _PasswordSetupSheetState();
}

class _PasswordSetupSheetState extends State<_PasswordSetupSheet> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  String? _mnemonic;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isDismissible,
      child: _VantSheet(
        showHandle: widget.isDismissible,
        bottomInset: MediaQuery.of(context).viewInsets.bottom,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _mnemonic == null
              ? _buildPasswordStep(context)
              : _buildMnemonicBackupStep(context, _mnemonic!),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(BuildContext context) {
    return Column(
      key: const ValueKey('password-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VantSheetTitle(title: widget.title),
        Text(
          S.of(context).walletPasswordHint,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.35,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ).marginOnly(bottom: 14.h),
        _PasswordTextField(
          controller: _passwordController,
          label: S.of(context).walletPassword,
        ).marginOnly(bottom: 12.h),
        _PasswordTextField(
          controller: _confirmPasswordController,
          label: S.of(context).confirmWalletPassword,
        ).marginOnly(bottom: 14.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: _vantFilledButtonStyle(context),
            onPressed: _isSubmitting ? null : _submit,
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildMnemonicBackupStep(BuildContext context, String mnemonic) {
    final words = mnemonic.split(' ');
    return Column(
      key: const ValueKey('mnemonic-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VantSheetTitle(title: S.of(context).backupMnemonic),
        Text(
          S.of(context).backupMnemonicTip,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.35,
            color: Theme.of(context).colorScheme.error,
          ),
        ).marginOnly(bottom: 14.h),
        _MnemonicWordGrid(words: words).marginOnly(bottom: 14.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: _vantFilledButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).mnemonicBackupConfirm),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (!widget.validatePassword(
      password,
      _confirmPasswordController.text.trim(),
    )) {
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await widget.onSubmit(password);
    if (!mounted) return;
    if (result is CreatedWalletBackup) {
      setState(() {
        _mnemonic = result.mnemonic;
        _isSubmitting = false;
      });
      return;
    }
    if (result == true) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}

class _VantSegmentedControl extends StatelessWidget {
  const _VantSegmentedControl({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: leftLabel,
            selected: leftSelected,
            onTap: () => onChanged(true),
          ),
          _SegmentItem(
            label: rightLabel,
            selected: !leftSelected,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.58),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MnemonicWordGrid extends StatelessWidget {
  const _MnemonicWordGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: words.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8.h,
          crossAxisSpacing: 8.w,
          childAspectRatio: 2.85,
        ),
        itemBuilder: (context, index) {
          return Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              '${index + 1}. ${words[index]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }
}

class _PasswordUnlockSheet extends StatefulWidget {
  const _PasswordUnlockSheet({
    required this.title,
    required this.detail,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String detail;
  final String submitLabel;
  final Future<bool> Function(String password) onSubmit;

  @override
  State<_PasswordUnlockSheet> createState() => _PasswordUnlockSheetState();
}

class _PasswordUnlockSheetState extends State<_PasswordUnlockSheet> {
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _VantSheet(
      bottomInset: MediaQuery.of(context).viewInsets.bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VantSheetTitle(title: widget.title),
          Text(
            widget.detail,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.35,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ).marginOnly(bottom: 14.h),
          _PasswordTextField(
            controller: _passwordController,
            label: S.of(context).walletPassword,
          ).marginOnly(bottom: 14.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: _vantFilledButtonStyle(context),
              onPressed: _isSubmitting ? null : _submit,
              child: Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }

    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit(password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}

class _PasswordTextField extends StatelessWidget {
  const _PasswordTextField({
    required this.controller,
    required this.label,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: _vantInputDecoration(
        context,
        labelText: label,
        hintText: hint,
        prefixIcon: Icons.lock_outline_rounded,
      ),
    );
  }
}

InputDecoration _vantInputDecoration(
  BuildContext context, {
  String? labelText,
  String? label,
  String? hintText,
  IconData? prefixIcon,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final appTheme = context.appTheme;
  final surfaceAlpha = Theme.of(context).brightness == Brightness.dark
      ? 0.08
      : 0.035;
  final borderColor =
      appTheme.inputBorderColor ?? colorScheme.outline.withValues(alpha: 0.22);
  return InputDecoration(
    filled: true,
    fillColor: colorScheme.onSurface.withValues(alpha: surfaceAlpha),
    labelText: labelText ?? label,
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(
            prefixIcon,
            size: 18.w,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
    labelStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.58),
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.36),
      fontSize: 12.sp,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
    ),
  );
}

ButtonStyle _vantFilledButtonStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    minimumSize: Size.fromHeight(44.h),
    elevation: 0,
    backgroundColor: colorScheme.primary,
    foregroundColor: colorScheme.onPrimary,
    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
  );
}

ButtonStyle _vantOutlinedButtonStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    minimumSize: Size.fromHeight(44.h),
    foregroundColor: colorScheme.primary,
    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.42)),
    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
  );
}
