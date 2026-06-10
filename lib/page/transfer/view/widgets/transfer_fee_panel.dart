import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../controller/transfer_controller.dart';
import 'transfer_styles.dart';

/// 转账手续费估算面板。
///
/// 根据 [TransferController] 的实时估算状态展示三种情况：正在查询、查询成功、
/// 查询失败或尚未输入有效信息。面板只负责展示，不直接发起 RPC 请求。
class TransferFeePanel extends StatelessWidget {
  const TransferFeePanel({
    super.key,
    required this.asset,
    required this.controller,
  });

  /// 当前转账资产，用于展示网络名、手续费币种和链配色。
  final ChainBalance asset;

  /// 转账控制器，提供手续费估算状态。
  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    final chainColor = transferChainColor(asset.chain);
    final estimate = controller.feeEstimate;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: chainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: chainColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chainColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.bolt_rounded, color: chainColor, size: 21.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).estimatedNetworkFee,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (controller.isEstimatingFee)
                  Row(
                    children: [
                      SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ).marginOnly(right: 6.w),
                      Text(
                        S.of(context).feeEstimating,
                        style: _feeTextStyle(context),
                      ),
                    ],
                  )
                else if (estimate != null)
                  Text(
                    estimate.isFallback
                        ? S.of(context).feeFallback(estimate.displayText)
                        : estimate.displayText,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                else
                  Text(
                    controller.feeEstimateUnavailable
                        ? S.of(context).feeUnavailable
                        : S.of(context).networkFeeAsset(asset.chain.symbol),
                    style: _feeTextStyle(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建手续费说明文本的统一样式。
  TextStyle _feeTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: 11.5.sp,
      height: 1.25,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
    );
  }
}
