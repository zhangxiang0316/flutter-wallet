import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';

/// 首页钱包相关底部弹窗的统一容器。
///
/// 封装 Vant 风格的圆角、顶部拖拽条、安全区和键盘底部间距，
/// 让创建、导入、解锁等面板保持同一套视觉规范。
class VantSheet extends StatelessWidget {
  const VantSheet({
    super.key,
    required this.child,
    this.bottomInset = 0,
    this.showHandle = true,
  });

  /// 弹窗内部具体内容。
  final Widget child;

  /// 键盘弹出时需要追加的底部间距，通常来自 [MediaQuery.viewInsets]。
  final double bottomInset;

  /// 是否展示顶部短横拖拽条。
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18.r,
              offset: Offset(0, -6.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16.w,
            showHandle ? 8.h : 18.h,
            16.w,
            bottomInset + 18.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ).marginOnly(bottom: 12.h),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页底部弹窗的统一标题样式。
class VantSheetTitle extends StatelessWidget {
  const VantSheetTitle({super.key, required this.title});

  /// 标题文本。
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
    ).marginOnly(bottom: 14.h);
  }
}

/// 两段式切换控件。
///
/// 当前用于导入钱包时在“助记词”和“私钥”两种输入模式之间切换。
class VantSegmentedControl extends StatelessWidget {
  const VantSegmentedControl({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onChanged,
    this.enabled = true,
  });

  /// 左侧选项文案。
  final String leftLabel;

  /// 右侧选项文案。
  final String rightLabel;

  /// true 表示左侧选中，false 表示右侧选中。
  final bool leftSelected;

  /// 选中项变化回调，参数含义同 [leftSelected]。
  final ValueChanged<bool> onChanged;

  /// 是否允许切换选项。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // 当前主题色用于未选中态文字和选中态强调色。
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          _SegmentItem(
            label: leftLabel,
            selected: leftSelected,
            enabled: enabled,
            onTap: () => onChanged(true),
          ),
          _SegmentItem(
            label: rightLabel,
            selected: !leftSelected,
            enabled: enabled,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

/// 两段式切换控件里的单个选项。
class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  /// 当前选项文案。
  final String label;

  /// 当前选项是否处于选中态。
  final bool selected;

  /// 当前选项是否允许点击。
  final bool enabled;

  /// 点击选项后的切换回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 当前主题色用于选中和未选中状态的文字颜色。
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 9.h),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.58),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// 钱包密码输入框。
///
/// 统一设置隐藏输入、锁图标和 Vant 风格输入框装饰。
class PasswordTextField extends StatelessWidget {
  const PasswordTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.enabled = true,
  });

  /// 外部持有的输入控制器，便于表单统一读取和释放。
  final TextEditingController controller;

  /// 输入框标签。
  final String label;

  /// 可选占位提示。
  final String? hint;

  /// 是否允许输入。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: true,
      decoration: vantInputDecoration(
        context,
        labelText: label,
        hintText: hint,
        prefixIcon: Icons.lock_outline_rounded,
      ),
    );
  }
}

/// 首页钱包弹窗里文本输入框的统一装饰。
InputDecoration vantInputDecoration(
  BuildContext context, {

  /// Material 原生 labelText 参数。
  String? labelText,

  /// 兼容旧调用的 label 参数，优先级低于 [labelText]。
  String? label,

  /// 输入框占位提示。
  String? hintText,

  /// 输入框左侧图标。
  IconData? prefixIcon,
}) {
  // 当前主题色用于输入框文字、图标和聚焦边框。
  final colorScheme = Theme.of(context).colorScheme;

  // 应用主题扩展可覆盖输入框边框色。
  final appTheme = context.appTheme;

  // 深色模式需要更高的填充不透明度，保证输入框层级清晰。
  final surfaceAlpha = Theme.of(context).brightness == Brightness.dark
      ? 0.08
      : 0.035;

  // 输入框默认边框色。
  final borderColor =
      appTheme.inputBorderColor ?? colorScheme.outline.withValues(alpha: 0.22);
  return InputDecoration(
    filled: true,
    fillColor: colorScheme.onSurface.withValues(alpha: surfaceAlpha),
    labelText: labelText ?? label,
    hintText: hintText,
    prefixIcon: prefixIcon == null
        ? null
        : Icon(
            prefixIcon,
            size: 18.w,
            color: colorScheme.onSurface.withValues(alpha: 0.45),
          ),
    labelStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.58),
      fontSize: 12.sp,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.36),
      fontSize: 12.sp,
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
    ),
  );
}

/// 首页钱包弹窗按钮里的 loading 文案。
///
/// 创建和导入钱包提交时复用该组件，保持按钮高度不变，只在文案左侧增加进度圈。
class VantButtonLoadingLabel extends StatelessWidget {
  const VantButtonLoadingLabel({
    super.key,
    required this.label,
    required this.loading,
  });

  /// 按钮文案。
  final String label;

  /// true 时展示进度圈。
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return Text(label);
    }

    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.62);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16.w,
          height: 16.w,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        SizedBox(width: 8.w),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// 首页钱包弹窗里的主按钮样式。
ButtonStyle vantFilledButtonStyle(BuildContext context) {
  // 主按钮跟随当前主题主色。
  final colorScheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    minimumSize: Size.fromHeight(44.h),
    elevation: 0,
    backgroundColor: colorScheme.primary,
    foregroundColor: colorScheme.onPrimary,
    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
  );
}

/// 首页钱包弹窗里的次级描边按钮样式。
ButtonStyle vantOutlinedButtonStyle(BuildContext context) {
  // 描边按钮使用主题主色，透明描边降低视觉重量。
  final colorScheme = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    minimumSize: Size.fromHeight(44.h),
    foregroundColor: colorScheme.primary,
    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.42)),
    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
  );
}
