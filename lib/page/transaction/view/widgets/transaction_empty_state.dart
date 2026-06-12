import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'transaction_history_styles.dart';

/// 交易记录页空态/加载态。
class TransactionEmptyState extends StatelessWidget {
  const TransactionEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : isLoading = false;

  const TransactionEmptyState.loading({super.key, required this.message})
    : isLoading = true,
      actionLabel = null,
      onAction = null;

  /// 展示文案。
  final String message;

  /// true 时展示加载指示器。
  final bool isLoading;

  /// 空态下展示的操作按钮文案。
  final String? actionLabel;

  /// 空态操作按钮点击回调。
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shouldShowAction =
        !isLoading && actionLabel != null && onAction != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 28.h),
      decoration: transactionPanelDecoration(context),
      child: Column(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: isLoading
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.receipt_long_outlined,
                    size: 22.w,
                    color: colorScheme.primary,
                  ),
          ),
          SizedBox(height: 12.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 12.sp,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (shouldShowAction) ...[
            SizedBox(height: 14.h),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(Icons.open_in_new_rounded, size: 16.w),
              label: Text(actionLabel!),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.28),
                ),
                minimumSize: Size(0, 34.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                textStyle: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
