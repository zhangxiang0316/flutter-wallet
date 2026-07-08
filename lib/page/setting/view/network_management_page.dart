import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../controller/network_management_controller.dart';
import '../../address_book/view/widgets/address_book_confirm_dialog.dart';
import 'widgets/network_form_sheet.dart';
import 'widgets/network_intro_card.dart';
import 'widgets/network_tile.dart';

@GetXRoutePage('/networkManagement')
/// 网络管理页面。
///
/// 第一版只允许用户新增 EVM 网络。内置链不可删除，但可以编辑名称、简称和 RPC；
/// 用户添加的链可以隐藏、编辑或删除。
// ignore: use_key_in_widget_constructors, must_be_immutable
class NetworkManagementPage
    extends BaseScaffoldPage<NetworkManagementController> {
  @override
  NetworkManagementController generateController() {
    return NetworkManagementController();
  }

  @override
  PreferredSizeWidget? getAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Theme.of(context).cardColor,
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
        S.of(context).networkManagement,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context).addNetwork,
          onPressed: () => _showAddNetworkSheet(context),
          icon: Icon(Icons.add_rounded, size: 22.w, color: colorScheme.primary),
        ),
      ],
    );
  }

  @override
  Widget? getBody(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          const NetworkIntroCard(),
          SizedBox(height: 12.h),
          ...controller.chains.map(
            (chain) => NetworkTile(
              chain: chain,
              healthReport: controller.healthReports[chain.id],
              isTesting: controller.testingChainIds.contains(chain.id),
              onEnabledChanged: chain.isBuiltin
                  ? null
                  : (enabled) => controller.setEnabled(chain, enabled),
              onEditPressed: () => _showEditNetworkSheet(context, chain),
              onRemovePressed: chain.isBuiltin
                  ? null
                  : () => _confirmRemoveChain(context, chain),
              onTestPressed: () => controller.testNetwork(chain),
              onSwitchRpcPressed: (rpcUrl) =>
                  controller.switchPrimaryRpc(chain, rpcUrl),
            ).marginOnly(bottom: 10.h),
          ),
        ],
      ),
    );
  }

  void _showAddNetworkSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => NetworkFormSheet(onSubmit: controller.addEvmChain),
    );
  }

  void _showEditNetworkSheet(BuildContext context, WalletChainConfig chain) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => NetworkFormSheet(
        initialChain: chain,
        onSubmit:
            ({
              required name,
              required symbol,
              required chainId,
              required rpcUrls,
              explorerApiUrl,
              explorerApiKey,
            }) {
              return controller.updateNetwork(
                chain: chain,
                name: name,
                symbol: symbol,
                rpcUrls: rpcUrls,
                explorerApiUrl: explorerApiUrl,
                explorerApiKey: explorerApiKey,
              );
            },
      ),
    );
  }

  Future<void> _confirmRemoveChain(
    BuildContext context,
    WalletChainConfig chain,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AddressBookConfirmDialog(
        title: S.of(dialogContext).removeNetwork,
        message: S.of(dialogContext).removeNetworkConfirm(chain.name),
        confirmText: S.of(dialogContext).removeNetwork,
        onConfirm: () => controller.removeChain(chain),
      ),
    );
  }
}
