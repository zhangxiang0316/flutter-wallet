import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'address_book_styles.dart';

/// 地址簿为空时展示的引导卡片。
///
/// 显示空态图标与"添加联系人"按钮，引导用户录入首个地址。
class AddressBookEmptyCard extends StatelessWidget {
  const AddressBookEmptyCard({super.key, required this.onAddPressed});

  /// 点击"添加联系人"按钮的回调。
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: panelDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            size: 34.w,
            color: colorScheme.primary,
          ),
          SizedBox(height: 8.h),
          Text(
            S.of(context).noContacts,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12.h),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(S.of(context).addAddressBookEntry),
          ),
        ],
      ),
    );
  }
}
