import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../controller/transfer_controller.dart';
import 'widgets/transfer_fee_panel.dart';
import 'widgets/transfer_form_panel.dart';
import 'widgets/transfer_hero.dart';
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

  /// 顶部 AppBar，仅提供页面标题和默认返回能力。
  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(title: Text(S.of(context!).transfer));
  }

  /// 页面主体。
  ///
  /// 如果路由参数缺失则展示不可用提示；参数有效时按顺序展示 Hero、表单、
  /// 手续费估算和提交成功面板。
  @override
  Widget? getBody() {
    final args = controller.arguments;
    if (args == null) {
      return const TransferUnavailablePanel();
    }

    final asset = args.asset;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransferHero(asset: asset),
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
    );
  }
}
