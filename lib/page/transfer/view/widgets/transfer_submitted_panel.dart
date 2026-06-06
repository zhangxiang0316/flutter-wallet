import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';
import '../../controller/transfer_controller.dart';

class TransferSubmittedPanel extends StatelessWidget {
  const TransferSubmittedPanel({super.key, required this.controller});

  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    final successColor = context.appTheme.successColor!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: successColor.withValues(alpha: 0.22)),
      ),
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
                  color: successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: successColor,
                  size: 22.w,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  S.of(context).transferSubmitted,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ).marginOnly(bottom: 14.h),
          Text(
            S.of(context).transactionHash,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: context.appTheme.dividerColor!.withValues(alpha: 0.45),
              ),
            ),
            child: SelectableText(
              controller.transactionHash,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ).marginOnly(bottom: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.copyTransactionHash,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(S.of(context).copyHash),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.backToWallet,
                  child: Text(S.of(context).backToWallet),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
