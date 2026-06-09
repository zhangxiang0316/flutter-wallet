import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'home_styles.dart';

/// 首页底部的本地私钥安全提示。
///
/// 提醒用户当前钱包密钥存储在本机，避免把安全说明分散在首页主体代码中。
class PrivateKeyNotice extends StatelessWidget {
  const PrivateKeyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用错误色强化本地私钥安全提示的重要性。
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      decoration: homePanelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18.w,
              color: colorScheme.error,
            ),
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
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  S.of(context).securityNoticeDetail,
                  style: TextStyle(
                    color: homeSubTextColor(context),
                    fontSize: 10.5.sp,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
