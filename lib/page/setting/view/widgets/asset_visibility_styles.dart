import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 资产显示设置页卡片统一样式。
///
/// 各链设置卡片和顶部说明卡片共用该装饰，保证背景、圆角和边框一致。
BoxDecoration assetVisibilityPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}
