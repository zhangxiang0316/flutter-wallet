import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 密码缓存过期时间选项。
///
/// 单选行，选中时高亮主色并显示勾选图标。
class ExpiryOption extends StatelessWidget {
  const ExpiryOption({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  /// 选项文案。
  final String title;

  /// 是否为当前选中项。
  final bool selected;

  /// 点击回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: selected
                      ? selectedColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.84),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Icon(
                Icons.check_rounded,
                size: 20.w,
                color: selectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
