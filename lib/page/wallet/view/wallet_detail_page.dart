import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/password_cache_service.dart';
import '../../../widget/secure_screen.dart';
import '../controller/wallet_detail_controller.dart';
import 'widgets/rename_wallet_sheet.dart';
import 'widgets/wallet_address_section.dart';
import 'widgets/wallet_detail_header.dart';
import 'widgets/wallet_password_unlock_sheet.dart';
import 'widgets/wallet_secret_section.dart';

@GetXRoutePage('/walletDetail')
/// 钱包详情页面。
///
/// 从首页左上角钱包入口进入，集中展示各链地址、钱包改名入口，以及经过密码
/// 校验后才可临时查看的私钥/助记词。
// ignore: use_key_in_widget_constructors, must_be_immutable
class WalletDetailPage extends BaseScaffoldPage<WalletDetailController> {
  /// 创建钱包详情控制器。
  @override
  WalletDetailController generateController() {
    return WalletDetailController();
  }

  /// 页面顶部导航栏。
  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 50.h,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: Get.back,
      ),
      centerTitle: true,
      title: Text(
        S.of(context!).walletDetails,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
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

  /// 页面主体内容。
  ///
  /// 钱包不存在时展示兜底提示；正常情况下分为钱包头部、地址列表和密钥查看区域。
  /// 整个页面包裹在 SecureScreen 中，防止截屏泄露私钥和助记词。
  @override
  Widget? getBody() {
    final wallet = controller.wallet;
    if (wallet == null) {
      return Center(
        child: Text(
          S.of(context!).transferUnavailable,
          style: TextStyle(fontSize: 13.sp),
        ),
      );
    }

    return SecureScreen(
      child: ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          WalletDetailHeader(
            wallet: wallet,
            isRenaming: controller.isRenamingWallet,
            onRenamePressed: () => _showRenameWalletSheet(wallet.name),
          ),
          SizedBox(height: 12.h),
          WalletAddressSection(wallet: wallet),
          SizedBox(height: 12.h),
          WalletSecretSection(
            privateKeyText: controller.privateKeyText,
            mnemonicText: controller.mnemonicText,
            hasMnemonic: controller.hasMnemonic,
            isUnlockingPrivateKey: controller.isUnlockingPrivateKey,
            isUnlockingMnemonic: controller.isUnlockingMnemonic,
            onUnlockPrivateKey: () => _showPasswordUnlockSheet(
              title: S.of(context!).viewPrivateKey,
              onSubmit: controller.unlockPrivateKey,
            ),
            onUnlockMnemonic: () => _showPasswordUnlockSheet(
              title: S.of(context!).viewMnemonic,
              onSubmit: controller.unlockMnemonic,
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 打开修改钱包名称的底部弹窗。
  void _showRenameWalletSheet(String currentName) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => RenameWalletSheet(
        currentName: currentName,
        onSubmit: controller.renameWallet,
      ),
    );
  }

  /// 打开密码解锁弹窗。
  ///
  /// 私钥和助记词共用该弹窗，具体解锁动作由控制器回调决定。
  void _showPasswordUnlockSheet({
    required String title,
    required Future<bool> Function(String password) onSubmit,
  }) async {
    final cachedPassword = await PasswordCacheService.getCachedPassword();
    if (!mounted) return;

    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => WalletPasswordUnlockSheet(
        title: title,
        onSubmit: onSubmit,
        cachedPassword: cachedPassword,
      ),
    );
  }
}
