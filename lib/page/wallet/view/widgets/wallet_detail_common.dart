import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_account.dart';

/// 钱包详情页通用白底面板装饰。
BoxDecoration walletDetailPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}

/// 复制文本到系统剪贴板并展示反馈。
void copyWalletDetailValue(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  Toast.show(S.of(context).copied);
}

/// 获取钱包头像首字母。
String walletDetailInitial(WalletAccount wallet) {
  final name = wallet.name.trim();
  if (name.isNotEmpty) {
    return name.characters.first.toUpperCase();
  }
  return 'W';
}

/// 钱包详情页通用分组面板。
class WalletDetailSectionPanel extends StatelessWidget {
  const WalletDetailSectionPanel({
    super.key,
    required this.title,
    required this.children,
  });

  /// 面板标题。
  final String title;

  /// 面板内的列表项。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
      decoration: walletDetailPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
          ).marginOnly(bottom: 8.h),
          ...children,
        ],
      ),
    );
  }
}

/// 钱包详情页通用列表行。
///
/// 用于地址和密钥区域，统一左侧图标、标题、说明和右侧操作按钮布局。
class WalletDetailPlainTile extends StatelessWidget {
  const WalletDetailPlainTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.subtitleMaxLines = 2,
  });

  /// 行左侧图标或徽标。
  final Widget leading;

  /// 行标题。
  final String title;

  /// 行说明或地址/密钥文本。
  final String subtitle;

  /// 行右侧操作区，例如复制或查看按钮。
  final Widget trailing;

  /// 说明文本最大行数。
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          leading,
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 10.5.sp,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          trailing,
        ],
      ),
    );
  }
}
