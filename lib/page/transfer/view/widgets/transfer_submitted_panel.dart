import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_transaction_record.dart';
import '../../controller/transfer_controller.dart';

/// 交易提交成功面板。
///
/// 显示链上广播返回的交易哈希，并提供复制哈希和返回首页两个动作。
/// 首页会根据返回结果决定是否刷新余额。
class TransferSubmittedPanel extends StatelessWidget {
  const TransferSubmittedPanel({super.key, required this.controller});

  /// 转账控制器，提供交易哈希和按钮回调。
  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    final successColor = context.appTheme.successColor!;
    final statusColor = _statusColor(context, controller.submittedStatus);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: successColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: successColor,
                  size: 22.w,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  S.of(context).transferSubmitted,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ).marginOnly(bottom: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              _statusText(context, controller.submittedStatus),
              style: TextStyle(
                color: statusColor,
                fontSize: 11.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ).marginOnly(bottom: 12.h),
          Text(
            S.of(context).transactionHash,
            style: TextStyle(
              fontSize: 11.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: context.appTheme.dividerColor!.withValues(alpha: 0.45),
              ),
            ),
            child: SelectableText(
              controller.transactionHash,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ).marginOnly(bottom: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.copyTransactionHash,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(
                    S.of(context).copyHash,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.refreshSubmittedStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    S.of(context).transactionRefreshStatus,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.openSubmittedTransactionExplorer,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    S.of(context).openBlockExplorer,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.backToWallet,
                  child: Text(
                    S.of(context).backToWallet,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, WalletTransactionStatus status) {
    return switch (status) {
      WalletTransactionStatus.success => context.appTheme.successColor!,
      WalletTransactionStatus.failed => Theme.of(context).colorScheme.error,
      WalletTransactionStatus.pending => const Color(0xFFF59E0B),
      WalletTransactionStatus.unknown => Theme.of(context).colorScheme.primary,
    };
  }

  String _statusText(BuildContext context, WalletTransactionStatus status) {
    final s = S.of(context);
    return switch (status) {
      WalletTransactionStatus.success => s.transactionStatusSuccess,
      WalletTransactionStatus.failed => s.transactionStatusFailed,
      WalletTransactionStatus.pending => s.transactionStatusPending,
      WalletTransactionStatus.unknown => s.transactionStatusUnknown,
    };
  }
}
