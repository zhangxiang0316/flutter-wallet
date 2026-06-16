import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../utils/transaction_risk_checker.dart';

/// 交易审查详情项
class ReviewItem {
  final String label;
  final String value;
  final Widget? icon;
  final bool highlight;
  final bool copyable;
  final VoidCallback? onTap;

  ReviewItem({
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
    this.copyable = false,
    this.onTap,
  });
}

/// 通用交易审查底部弹窗
///
/// 在用户输入密码之前，显示完整的交易详情，包括：
/// - 发送方、接收方、金额、手续费、网络等
/// - 风险警告（大额转账、新地址等）
/// - 总计金额
///
/// 用户必须先审查这些信息，点击"Approve"后才会进入密码认证步骤。
class TransactionReviewSheet extends StatelessWidget {
  final String title;
  final List<ReviewItem> items;
  final List<TransactionRisk> risks;
  final String? dappName;
  final String? dappUrl;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const TransactionReviewSheet({
    Key? key,
    required this.title,
    required this.items,
    this.risks = const [],
    this.dappName,
    this.dappUrl,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(context),

            // DApp 信息（如果有）
            if (dappName != null) _buildDAppInfo(context),

            // 交易详情
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),

                    // 风险警告
                    if (risks.isNotEmpty) ...[
                      _buildRiskWarnings(context),
                      SizedBox(height: 20.h),
                    ],

                    // 交易详情列表
                    ...items.map((item) => _buildDetailItem(context, item)),

                    SizedBox(height: 20.h),

                    // 不可逆提示
                    _buildWarningNote(context),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),

            // 底部按钮
            _buildButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onReject,
            icon: Icon(Icons.close, size: 24.sp),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildDAppInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.language,
              size: 20.sp,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dappName!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dappUrl != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    dappUrl!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskWarnings(BuildContext context) {
    return Column(
      children: risks.map((risk) {
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: risk.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: risk.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                risk.icon,
                color: risk.color,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  risk.message,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: risk.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailItem(BuildContext context, ReviewItem item) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 6.h),
          InkWell(
            onTap: item.onTap ?? (item.copyable ? () => _copyToClipboard(context, item.value) : null),
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: item.highlight
                    ? theme.primaryColor.withOpacity(0.1)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: item.highlight
                      ? theme.primaryColor.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    item.icon!,
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: item.highlight ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item.copyable)
                    Icon(
                      Icons.copy,
                      size: 16.sp,
                      color: Colors.grey,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningNote(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18.sp,
            color: Colors.amber.shade700,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'This transaction cannot be reversed. Please verify all details carefully.',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.amber.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    final theme = Theme.of(context);
    final highestRisk = TransactionRiskChecker.getHighestRiskLevel(risks);
    final isHighRisk = highestRisk == RiskLevel.high;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Text(
                'Reject',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: onApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighRisk ? Colors.red : theme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Approve & Sign',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'Address copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 2),
      margin: EdgeInsets.all(16.w),
    );
  }

  /// 显示交易审查弹窗的便捷方法
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required List<ReviewItem> items,
    List<TransactionRisk> risks = const [],
    String? dappName,
    String? dappUrl,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TransactionReviewSheet(
          title: title,
          items: items,
          risks: risks,
          dappName: dappName,
          dappUrl: dappUrl,
          onApprove: () => Navigator.of(context).pop(true),
          onReject: () => Navigator.of(context).pop(false),
        );
      },
    );
  }
}
