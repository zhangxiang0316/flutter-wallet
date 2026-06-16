import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

import '../../../wallet/services/walletconnect_service.dart';
import '../controller/walletconnect_controller.dart';

/// 会话提案数据类
class SessionProposal {
  final int id;
  final ProposalData params;

  SessionProposal({
    required this.id,
    required this.params,
  });
}

/// 连接请求确认弹窗
class ConnectionRequestSheet extends StatelessWidget {
  final SessionProposal proposal;
  final String walletAddress;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ConnectionRequestSheet({
    Key? key,
    required this.proposal,
    required this.walletAddress,
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
            _buildHeader(context),
            _buildDAppInfo(context),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPermissions(context),
                    SizedBox(height: 20.h),
                    _buildWalletInfo(context),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
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
              'Connect to DApp',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.language, size: 28.sp, color: theme.primaryColor),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal.name,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  proposal.url,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissions(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 20.sp, color: theme.primaryColor),
              SizedBox(width: 8.w),
              Text('This DApp will be able to:', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 12.h),
          _buildPermissionItem(context, 'View your wallet balance'),
          _buildPermissionItem(context, 'Request transaction approval'),
          _buildPermissionItem(context, 'Request message signatures'),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.only(top: 4.h),
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _buildWalletInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connecting with', style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.account_balance_wallet, size: 18.sp, color: Colors.white),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  walletAddress,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Text('Reject', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: onApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                elevation: 0,
              ),
              child: Text('Connect', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> show({
    required BuildContext context,
    required SessionProposal proposal,
    required String walletAddress,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConnectionRequestSheet(
        proposal: proposal,
        walletAddress: walletAddress,
        onApprove: () => Navigator.of(context).pop(true),
        onReject: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
