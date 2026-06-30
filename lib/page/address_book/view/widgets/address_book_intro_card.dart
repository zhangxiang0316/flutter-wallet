import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'address_book_styles.dart';

/// 地址簿页面顶部的引导卡片。
///
/// 在转账选择模式下显示当前链名称，普通模式下展示地址簿标题与使用提示。
class AddressBookIntroCard extends StatelessWidget {
  const AddressBookIntroCard({
    super.key,
    this.chainName,
    required this.selectable,
  });

  /// 当前链名称，仅在 [selectable] 为 true 时用于标题拼接。
  final String? chainName;

  /// 是否为转账页的选择模式。
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = selectable && (chainName?.isNotEmpty ?? false)
        ? '${S.of(context).selectContact} · $chainName'
        : S.of(context).addressBook;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: panelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.contacts_rounded,
              size: 18.w,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  S.of(context).addressBookTip,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 11.5.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
