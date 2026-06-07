import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';

class HomeActionRow extends StatelessWidget {
  const HomeActionRow({
    super.key,
    required this.onAddWallet,
    required this.onRemove,
  });

  final VoidCallback onAddWallet;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HomeActionButton(
          filled: true,
          onPressed: onAddWallet,
          icon: Icons.add_rounded,
          label: S.of(context).addWallet,
        ),
        SizedBox(width: 12.w),
        _HomeActionButton(
          filled: false,
          destructive: true,
          onPressed: onRemove,
          icon: Icons.delete_outline_rounded,
          label: S.of(context).removeWallet,
        ),
      ],
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.filled,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = filled
        ? Colors.white
        : destructive
        ? colorScheme.error
        : colorScheme.onSurface;
    final background = filled
        ? colorScheme.primary
        : destructive
        ? colorScheme.error.withValues(alpha: 0.06)
        : Theme.of(context).cardColor;
    return Expanded(
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 42.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: filled
                  ? null
                  : Border.all(
                      color: destructive
                          ? colorScheme.error.withValues(alpha: 0.18)
                          : context.appTheme.dividerColor!.withValues(
                              alpha: 0.6,
                            ),
                    ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.18),
                        blurRadius: 12.r,
                        offset: Offset(0, 6.h),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18.w,
                  color: foreground,
                ).marginOnly(right: 7.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
