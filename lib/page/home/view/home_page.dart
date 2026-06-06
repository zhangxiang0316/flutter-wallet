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
            ? [
                EmptyWalletCard(
                  onCreateWallet: controller.createWallet,
                  onImportWallet: _showImportSheet,
                ),
              ]
            : [
                WalletOverviewCard(
                  wallet: wallet,
                  totalAssetsText: controller.totalAssetsText,
                ),
                SizedBox(height: 16.h),
                HomeActionRow(
                  isLoading: controller.isLoading,
                  onRefresh: controller.refreshBalances,
                  onRemove: controller.removeWallet,
                ),
                SizedBox(height: 16.h),
                ChainSection(
                  wallet: wallet,
                  balances: controller.balances,
                  isLoading: controller.isLoading,
                  onTransferPressed: _openTransferPage,
                ),
                SizedBox(height: 16.h),
                const PrivateKeyNotice(),
              ],
      ),
    );
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
