import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../page/transfer/controller/transfer_controller.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../home/controller/home_controller.dart';
import 'widgets/chain_section.dart';
import 'widgets/empty_wallet_card.dart';
import 'widgets/home_action_row.dart';
import 'widgets/private_key_notice.dart';
import 'widgets/wallet_overview_card.dart';

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
    return AppBar(
      backgroundColor: Theme.of(context!).scaffoldBackgroundColor,
      titleSpacing: 16.w,
      toolbarHeight: 54.h,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
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
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              S.of(context!).appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据本地是否已有钱包，切换空钱包引导或钱包资产面板。
  @override
  Widget? getBody() {
    final wallet = controller.wallet;
    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: wallet == null
            ? [
                EmptyWalletCard(
                  onCreateWallet: controller.createWallet,
                  onImportWallet: _showImportSheet,
                ),
              ]
            : [
                WalletOverviewCard(
                  wallet: wallet,
                  wallets: controller.wallets,
                  totalAssetsText: controller.totalAssetsText,
                  onWalletSelected: controller.switchWallet,
                ),
                SizedBox(height: 16.h),
                HomeActionRow(
                  onAddWallet: _showAddWalletSheet,
                  onRemove: controller.removeWallet,
                ),
                SizedBox(height: 16.h),
                ChainSection(
                  wallet: wallet,
                  balances: controller.balances,
                  isLoading: controller.isLoading,
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
      onRefresh: controller.refreshBalances,
      child: _HomeBackground(child: content),
    );
  }

  /// 导入私钥的底部弹窗，提交后由控制器校验并持久化钱包。
  void _showImportSheet() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context!).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 4.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context!).importPrivateKey,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ).marginOnly(bottom: 12.h),
              TextField(
                controller: textController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.onSurface.withValues(alpha: 0.04),
                  hintText: S.of(context!).privateKeyHint,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.22),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                ),
              ).marginOnly(bottom: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(42.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
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

  void _showAddWalletSheet() {
    showModalBottomSheet(
      context: context!,
      showDragHandle: true,
      backgroundColor: Theme.of(context!).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context!).addWallet,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
              ).marginOnly(bottom: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(42.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await controller.createWallet();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(S.of(context!).createWallet),
                ),
              ).marginOnly(bottom: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.fromHeight(42.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showImportSheet();
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

class _HomeBackground extends StatelessWidget {
  const _HomeBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
          stops: const [0, 0.34, 1],
        ),
      ),
      child: child,
    );
  }
}
