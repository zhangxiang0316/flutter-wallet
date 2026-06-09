import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

BoxDecoration assetVisibilityPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}
