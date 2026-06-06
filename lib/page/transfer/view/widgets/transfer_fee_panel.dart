import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../controller/transfer_controller.dart';
import 'transfer_styles.dart';

class TransferFeePanel extends StatelessWidget {
  const TransferFeePanel({
    super.key,
    required this.asset,
    required this.controller,
  });

  final ChainBalance asset;
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
                    fontSize: 14.sp,
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
                      fontSize: 15.sp,
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

  TextStyle _feeTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: 12.sp,
      height: 1.25,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
    );
  }
}
