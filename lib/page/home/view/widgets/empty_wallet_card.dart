import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'home_styles.dart';

/// 首页无钱包时展示的引导卡片。
///
/// 当本地没有钱包账户时，首页只展示这个卡片，引导用户创建新钱包或导入已有钱包。
class EmptyWalletCard extends StatelessWidget {
  const EmptyWalletCard({
    super.key,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  /// 打开创建钱包密码设置流程。
  final VoidCallback onCreateWallet;

  /// 打开助记词/私钥导入流程。
  final VoidCallback onImportWallet;

  @override
  Widget build(BuildContext context) {
    // 使用当前主题色作为空钱包图标和主按钮强调色。
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
      decoration: homePanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet,
              size: 27.w,
              color: colorScheme.primary,
            ),
          ).marginOnly(bottom: 14.h),
          Text(
            S.of(context).walletEmptyTitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
          ).marginOnly(bottom: 8.h),
          Text(
            S.of(context).walletEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.42,
              color: homeSubTextColor(context),
            ),
          ).marginOnly(bottom: 20.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(44.h),
                elevation: 0,
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
                minimumSize: Size.fromHeight(44.h),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.42),
                ),
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
