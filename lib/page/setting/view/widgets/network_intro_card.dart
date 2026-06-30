import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'network_styles.dart';

/// 网络管理页面顶部的引导提示卡片。
///
/// 展示网络管理的基本说明文案，使用图标 + 文字的横排布局。
class NetworkIntroCard extends StatelessWidget {
  const NetworkIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(13.w),
      decoration: panelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.hub_outlined,
              color: colorScheme.primary,
              size: 18.w,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              S.of(context).networkManagementTip,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontSize: 11.sp,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
