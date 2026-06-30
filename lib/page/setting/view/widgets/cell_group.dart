import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 密码缓存设置页面中的分组容器。
///
/// 可选标题文案，内部子项通过分割线自动间隔。
class CellGroup extends StatelessWidget {
  const CellGroup({super.key, this.title, required this.children});

  /// 分组标题，为 null 时不显示。
  final String? title;

  /// 分组内的子项列表。
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 7.h),
            child: Text(
              title!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Divider(height: 1, indent: 16.w, color: borderColor),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
