import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';

class VantSheet extends StatelessWidget {
  const VantSheet({
    super.key,
    required this.child,
    this.bottomInset = 0,
    this.showHandle = true,
  });

  final Widget child;
  final double bottomInset;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18.r,
              offset: Offset(0, -6.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            showHandle ? 8.h : 18.h,
            16.w,
            bottomInset + 18.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ).marginOnly(bottom: 12.h),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class VantSheetTitle extends StatelessWidget {
  const VantSheetTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
    ).marginOnly(bottom: 14.h);
  }
}

class VantSegmentedControl extends StatelessWidget {
  const VantSegmentedControl({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: leftLabel,
            selected: leftSelected,
            onTap: () => onChanged(true),
          ),
          _SegmentItem(
            label: rightLabel,
            selected: !leftSelected,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.58),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordTextField extends StatelessWidget {
  const PasswordTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: vantInputDecoration(
        context,
        labelText: label,
        hintText: hint,
        prefixIcon: Icons.lock_outline_rounded,
      ),
    );
  }
}

InputDecoration vantInputDecoration(
  BuildContext context, {
  String? labelText,
  String? label,
  String? hintText,
  IconData? prefixIcon,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final appTheme = context.appTheme;
  final surfaceAlpha = Theme.of(context).brightness == Brightness.dark
      ? 0.08
      : 0.035;
  final borderColor =
      appTheme.inputBorderColor ?? colorScheme.outline.withValues(alpha: 0.22);
  return InputDecoration(
    filled: true,
    fillColor: colorScheme.onSurface.withValues(alpha: surfaceAlpha),
    labelText: labelText ?? label,
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(
            prefixIcon,
            size: 18.w,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
    labelStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.58),
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.36),
      fontSize: 12.sp,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
    ),
  );
}

ButtonStyle vantFilledButtonStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    minimumSize: Size.fromHeight(44.h),
    elevation: 0,
    backgroundColor: colorScheme.primary,
    foregroundColor: colorScheme.onPrimary,
    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
  );
}

ButtonStyle vantOutlinedButtonStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    minimumSize: Size.fromHeight(44.h),
    foregroundColor: colorScheme.primary,
    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.42)),
    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
  );
}
