import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_account.dart';
import 'wallet_detail_common.dart';

/// 钱包详情页顶部信息区。
///
/// 展示钱包头像、名称、多链钱包说明和改名按钮。
class WalletDetailHeader extends StatelessWidget {
  const WalletDetailHeader({
    super.key,
    required this.wallet,
    required this.isRenaming,
    required this.onRenamePressed,
  });

  /// 当前钱包账户。
  final WalletAccount wallet;

  /// 当前是否正在提交钱包改名。
  final bool isRenaming;

  /// 点击编辑钱包名称后的回调。
  final VoidCallback onRenamePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: walletDetailPanelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, const Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              walletDetailInitial(wallet),
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  S.of(context).primaryMultiChainWallet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tight(Size(34.w, 34.w)),
            padding: EdgeInsets.zero,
            onPressed: isRenaming ? null : onRenamePressed,
            icon: isRenaming
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(strokeWidth: 2.w),
                  )
                : Icon(
                    Icons.edit_rounded,
                    size: 17.w,
                    color: colorScheme.primary,
                  ),
            tooltip: S.of(context).editWalletName,
          ),
        ],
      ),
    );
  }
}
