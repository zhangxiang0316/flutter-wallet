import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/adapters/default_chain_adapter_registry.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../controller/transfer_controller.dart';
import 'transfer_review_flow.dart';
import 'transfer_styles.dart';

/// 转账表单面板。
///
/// 包含收款地址、转账金额和确认按钮。点击确认后先进行本地输入校验，
/// 再弹出钱包密码输入框，由控制器完成私钥解锁和链上提交。
class TransferFormPanel extends StatelessWidget {
  const TransferFormPanel({
    super.key,
    required this.asset,
    required this.controller,
  });

  /// 当前要转出的资产。
  final ChainBalance asset;

  /// 页面控制器，持有输入框和提交状态。
  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: transferPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 22.w,
                  color: colorScheme.primary,
                ),
              ).marginOnly(right: 10.w),
              Text(
                S.of(context).transferDetails,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ).marginOnly(bottom: 16.h),
          TextField(
            controller: controller.addressController,
            enabled: !controller.isSubmitting,
            style: transferInputTextStyle(context),
            decoration: transferInputDecoration(
              context,
              label: S.of(context).recipientAddress,
              hint: _addressHint(asset),
              icon: Icons.account_circle_outlined,
            ),
          ).marginOnly(bottom: 12.h),
          TextField(
            controller: controller.amountController,
            enabled: !controller.isSubmitting,
            style: transferInputTextStyle(context),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: transferInputDecoration(
              context,
              label: S.of(context).transferAmount,
              icon: Icons.payments_outlined,
              suffix: asset.symbol,
            ),
          ).marginOnly(bottom: 2.h),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: S.of(context).transferMax,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size(64.w, 38.h),
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  visualDensity: VisualDensity.compact,
                  textStyle: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: controller.isSubmitting
                    ? null
                    : controller.fillMaximumAmount,
                child: Text(S.of(context).transferMax),
              ),
            ),
          ).marginOnly(bottom: 8.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: controller.isSubmitting
                  ? null
                  : () => TransferReviewFlow.show(context, controller),
              icon: controller.isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.outbound_rounded),
              label: Text(
                S.of(context).reviewTransfer,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 根据链类型返回地址输入框占位提示。
  String _addressHint(ChainBalance asset) {
    final chain = asset.chainRef;
    return createDefaultChainAdapterRegistry()
        .require(chain)
        .presentation(chain)
        .addressHint;
  }
}
