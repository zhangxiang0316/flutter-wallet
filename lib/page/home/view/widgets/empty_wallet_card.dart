import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'home_styles.dart';

class EmptyWalletCard extends StatelessWidget {
  const EmptyWalletCard({
    super.key,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  final VoidCallback onCreateWallet;
  final VoidCallback onImportWallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: homePanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              size: 27.w,
              color: colorScheme.primary,
            ),
          ).marginOnly(bottom: 14.h),
          Text(
            S.of(context).walletEmptyTitle,
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800),
          ).marginOnly(bottom: 8.h),
          Text(
            S.of(context).walletEmptySubtitle,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.42,
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ).marginOnly(bottom: 20.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(42.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: onCreateWallet,
              icon: const Icon(Icons.add),
              label: Text(S.of(context).createWallet),
            ),
          ).marginOnly(bottom: 10.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(42.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: onImportWallet,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(S.of(context).importWallet),
            ),
          ),
        ],
      ),
    );
  }
}
