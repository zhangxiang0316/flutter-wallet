import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../address_book/view/address_book_page.dart';
import '../controller/transfer_controller.dart';
import 'widgets/transfer_fee_panel.dart';
import 'widgets/transfer_address_scanner_page.dart';
import 'widgets/transfer_form_panel.dart';
import 'widgets/transfer_hero.dart';
import 'widgets/transfer_selector_row.dart';
import 'widgets/transfer_submitted_panel.dart';
import 'widgets/transfer_unavailable_panel.dart';

@GetXRoutePage('/transfer')
/// 转账页面。
///
/// 页面由首页资产列表进入，接收 [TransferPageArguments] 后展示资产摘要、转账表单、
/// 手续费估算和交易提交结果。具体提交逻辑由 [TransferController] 管理。
// ignore: use_key_in_widget_constructors, must_be_immutable
class TransferPage extends BaseScaffoldPage<TransferController> {
  /// 创建转账页面控制器。
  @override
  TransferController generateController() {
    return TransferController();
  }

  /// 顶部 AppBar，提供页面标题、默认返回和扫码填地址能力。
  @override
  PreferredSizeWidget? getAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        S.of(context).transfer,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context).chooseFromAddressBook,
          onPressed: controller.isSubmitting ? null : _chooseRecipientAddress,
          icon: Icon(Icons.contacts_rounded, size: 21.w),
        ),
        IconButton(
          tooltip: S.of(context).scanRecipientAddress,
          onPressed: controller.isSubmitting
              ? null
              : () => _scanRecipientAddress(context),
          icon: Icon(Icons.qr_code_scanner_rounded, size: 21.w),
        ),
      ],
    );
  }

  /// 页面主体。
  ///
  /// 如果路由参数缺失则展示不可用提示；参数有效时按顺序展示 Hero、表单、
  /// 手续费估算和提交成功面板。
  @override
  Widget? getBody(BuildContext context) {
    final args = controller.arguments;
    final asset = controller.currentAsset;
    if (args == null || asset == null) {
      return const TransferUnavailablePanel();
    }

    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TransferHero(asset: asset),
            SizedBox(height: 16.h),
            TransferSelectorRow(
              chains: controller.availableChains,
              selectedAsset: asset,
              assets: controller.assetsForSelectedChain(),
              isEnabled: !controller.isSubmitting,
              onChainSelected: controller.selectChain,
              onAssetSelected: controller.selectAsset,
            ),
            SizedBox(height: 16.h),
            TransferFormPanel(asset: asset, controller: controller),
            SizedBox(height: 16.h),
            TransferFeePanel(asset: asset, controller: controller),
            if (controller.transactionHash.isNotEmpty) ...[
              SizedBox(height: 16.h),
              TransferSubmittedPanel(controller: controller),
            ],
          ],
        ),
      ),
    );
  }

  /// 打开扫码页面，并把扫码结果写入收款地址输入框。
  Future<void> _scanRecipientAddress(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const TransferAddressScannerPage(),
        fullscreenDialog: true,
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    controller.fillRecipientAddressFromScan(result);
  }

  /// 从地址簿选择当前链的收款人。
  Future<void> _chooseRecipientAddress() async {
    final asset = controller.currentAsset;
    if (asset == null) return;
    final result = await Get.toNamed(
      RouteTable.addressBook,
      arguments: AddressBookPageArguments(
        chainId: asset.chainId,
        chainName: asset.chainConfig?.name ?? asset.chainRef.name,
        selectable: true,
      ),
    );
    if (result is! String || result.trim().isEmpty) return;
    controller.fillRecipientAddressFromBook(result);
  }
}
