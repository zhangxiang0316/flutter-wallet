import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';

class HomeActionRow extends StatelessWidget {
  const HomeActionRow({super.key, required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HomeActionButton(
          filled: false,
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = filled ? Colors.white : colorScheme.onSurface;
    return Expanded(
      child: Material(
        color: filled ? colorScheme.primary : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: filled
                  ? null
                  : Border.all(
                      color: context.appTheme.dividerColor!.withValues(
                        alpha: 0.6,
                      ),
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18.w,
                  color: foreground,
                ).marginOnly(right: 7.w),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
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
