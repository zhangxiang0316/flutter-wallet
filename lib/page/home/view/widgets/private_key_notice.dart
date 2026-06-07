import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';

class PrivateKeyNotice extends StatelessWidget {
  const PrivateKeyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20.w,
            color: Theme.of(context).colorScheme.error,
          ).marginOnly(right: 9.w, top: 1.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).securityNotice,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  S.of(context).securityNoticeDetail,
                  style: TextStyle(fontSize: 10.5.sp, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
