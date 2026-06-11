import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'asset_visibility_styles.dart';

/// 资产显示设置页顶部说明卡片。
///
/// 用简短文案解释当前页面的作用，避免用户误以为隐藏资产会删除链上余额。
class VisibilityIntroCard extends StatelessWidget {
  const VisibilityIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    // 当前主题色用于说明图标和辅助文字。
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: assetVisibilityPanelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.visibility_outlined,
              size: 18.w,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              S.of(context).assetVisibilityTip,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 11.sp,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
