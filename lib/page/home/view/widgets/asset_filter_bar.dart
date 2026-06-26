import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'home_styles.dart';

/// 首页资产显示辅助开关。
class AssetFilterBar extends StatelessWidget {
  const AssetFilterBar({
    super.key,
    required this.hideZeroBalances,
    required this.onHideZeroChanged,
  });

  final bool hideZeroBalances;
  final ValueChanged<bool> onHideZeroChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final inactiveColor = homeSubTextColor(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        toggled: hideZeroBalances,
        label: S.of(context).hideZeroBalances,
        child: Material(
          color: hideZeroBalances
              ? activeColor.withValues(alpha: 0.11)
              : Theme.of(context).cardColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999.r),
          child: InkWell(
            onTap: () => onHideZeroChanged(!hideZeroBalances),
            borderRadius: BorderRadius.circular(999.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(8.w, 5.h, 6.w, 5.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(
                  color: hideZeroBalances
                      ? activeColor.withValues(alpha: 0.22)
                      : homeDividerColor(context).withValues(alpha: 0.72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 10.r,
                    offset: Offset(0, 3.h),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22.w,
                    height: 22.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hideZeroBalances
                          ? activeColor
                          : inactiveColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hideZeroBalances
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 13.w,
                      color: hideZeroBalances
                          ? colorScheme.onPrimary
                          : inactiveColor,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    S.of(context).hideZeroBalances,
                    style: TextStyle(
                      color: hideZeroBalances ? activeColor : inactiveColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
