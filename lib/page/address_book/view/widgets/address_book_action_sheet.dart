import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Vant 风格底部操作面板。
///
/// 展示一组操作项（编辑、删除等），底部通过间距分隔后放置取消按钮。
/// 点击操作项或取消按钮后自动关闭。
class AddressBookActionSheet extends StatelessWidget {
  const AddressBookActionSheet({
    super.key,
    required this.actions,
    this.cancelText,
  });

  /// 操作项列表，每项包含名称和点击回调。
  final List<AddressBookAction> actions;

  /// 取消按钮文案，为 null 时不显示取消按钮。
  final String? cancelText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16.h),
            ...actions.map(
              (action) => _ActionItem(
                label: action.label,
                icon: action.icon,
                color: action.color,
                onTap: () {
                  Navigator.of(context).pop();
                  action.onTap();
                },
              ),
            ),
            if (cancelText != null) ...[
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                height: 1,
                color: colorScheme.outline.withValues(alpha: 0.08),
              ),
              _ActionItem(
                label: cancelText!,
                onTap: () => Navigator.of(context).pop(),
                isCancel: true,
              ),
            ],
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

/// Vant 风格操作面板中的单个操作项。
class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.isCancel = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final bool isCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor =
        color ??
        (isCancel
            ? colorScheme.onSurface.withValues(alpha: 0.58)
            : colorScheme.onSurface);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.w, color: itemColor),
                SizedBox(width: 6.w),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: isCancel ? FontWeight.w600 : FontWeight.w700,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 操作面板中的单个操作项数据。
class AddressBookAction {
  const AddressBookAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
  });

  /// 操作名称。
  final String label;

  /// 点击回调。
  final VoidCallback onTap;

  /// 可选的图标。
  final IconData? icon;

  /// 可选的文字颜色（删除等危险操作可传入红色）。
  final Color? color;
}
