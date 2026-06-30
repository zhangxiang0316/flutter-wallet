import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_address_book_entry.dart';
import 'address_book_styles.dart';

/// 地址簿单条联系人条目。
///
/// 展示联系人名称、链名称、地址缩略和备注，右侧提供更多操作按钮。
/// 选择模式下点击整行可返回该条地址。
class AddressBookEntryTile extends StatelessWidget {
  const AddressBookEntryTile({
    super.key,
    required this.entry,
    required this.selectable,
    required this.onTap,
    required this.onMorePressed,
  });

  /// 联系人数据。
  final WalletAddressBookEntry entry;

  /// 是否为转账页的选择模式。
  final bool selectable;

  /// 点击整行的回调，仅选择模式下有效。
  final VoidCallback? onTap;

  /// 点击右侧更多按钮的回调。
  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: panelDecoration(context),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  selectable
                      ? Icons.call_made_rounded
                      : Icons.person_outline_rounded,
                  color: colorScheme.primary,
                  size: 18.w,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          entry.chainName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      shortAddress(entry.address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.note.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        entry.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.46),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selectable)
                IconButton(
                  tooltip: S.of(context).more,
                  onPressed: onMorePressed,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 20.w,
                    color: colorScheme.onSurface.withValues(alpha: 0.42),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
