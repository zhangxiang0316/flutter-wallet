import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'home_styles.dart';

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
    return Column(
      children: [
        _AddWalletButton(onPressed: onAddWallet),
        SizedBox(height: 8.h),
        _RemoveWalletButton(onPressed: onRemove),
      ],
    );
  }
}

class _AddWalletButton extends StatelessWidget {
  const _AddWalletButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          width: double.infinity,
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: homeDividerColor(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 22.w,
                color: colorScheme.onSurface.withValues(alpha: 0.76),
              ).marginOnly(right: 8.w),
              Flexible(
                child: Text(
                  S.of(context).addWallet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveWalletButton extends StatelessWidget {
  const _RemoveWalletButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.error,
          minimumSize: Size(0, 34.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          textStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
        ),
        icon: Icon(Icons.delete_outline_rounded, size: 15.w),
        label: Text(S.of(context).removeWallet),
      ),
    );
  }
}
