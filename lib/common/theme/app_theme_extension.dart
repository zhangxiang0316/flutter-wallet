import 'package:flutter/material.dart';

/// 应用自定义主题扩展
/// 用于定义 ColorScheme 之外的自定义颜色
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // 自定义颜色
  final Color? successColor; // 成功色
  final Color? warningColor; // 警告色
  final Color? infoColor; // 信息色
  final Color? dividerColor; // 分割线颜色
  final Color? shadowColor; // 阴影颜色
  final Color? shimmerBaseColor; // 骨架屏基础色
  final Color? shimmerHighlightColor; // 骨架屏高亮色
  final Color? inputBackgroundColor; // 输入框背景色
  final Color? inputBorderColor; // 输入框边框色
  final Color? tagBackgroundColor; // 标签背景色
  final Color? tagTextColor; // 标签文字色
  final Color? bottomNavBarColor; // 底部导航栏背景色
  final Color? cardShadowColor; // 卡片阴影色

  const AppThemeExtension({
    this.successColor,
    this.warningColor,
    this.infoColor,
    this.dividerColor,
    this.shadowColor,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.inputBackgroundColor,
    this.inputBorderColor,
    this.tagBackgroundColor,
    this.tagTextColor,
    this.bottomNavBarColor,
    this.cardShadowColor,
  });

  /// 亮色主题
  static AppThemeExtension light() {
    return const AppThemeExtension(
      successColor: Color(0xFF4CAF50), // 绿色
      warningColor: Color(0xFFFF9800), // 橙色
      infoColor: Color(0xFF2196F3), // 蓝色
      dividerColor: Color(0xFFE0E0E0), // 浅灰色分割线
      shadowColor: Color(0x1A000000), // 10% 黑色阴影
      shimmerBaseColor: Color(0xFFE0E0E0), // 骨架屏基础色
      shimmerHighlightColor: Color(0xFFF5F5F5), // 骨架屏高亮色
      inputBackgroundColor: Color(0xFFFAFAFA), // 输入框背景
      inputBorderColor: Color(0xFFE0E0E0), // 输入框边框
      tagBackgroundColor: Color(0xFFE3F2FD), // 标签背景（浅蓝）
      tagTextColor: Color(0xFF1976D2), // 标签文字（深蓝）
      bottomNavBarColor: Colors.white, // 底部导航栏白色
      cardShadowColor: Color(0x0D000000), // 卡片阴影（5% 黑色）
    );
  }

  /// 暗色主题
  static AppThemeExtension dark() {
    return const AppThemeExtension(
      successColor: Color(0xFF66BB6A), // 浅绿色
      warningColor: Color(0xFFFFB74D), // 浅橙色
      infoColor: Color(0xFF42A5F5), // 浅蓝色
      dividerColor: Color(0xFF424242), // 深灰色分割线
      shadowColor: Color(0x33000000), // 20% 黑色阴影
      shimmerBaseColor: Color(0xFF424242), // 骨架屏基础色
      shimmerHighlightColor: Color(0xFF616161), // 骨架屏高亮色
      inputBackgroundColor: Color(0xFF2C2C2C), // 输入框背景
      inputBorderColor: Color(0xFF424242), // 输入框边框
      tagBackgroundColor: Color(0xFF1E3A5F), // 标签背景（深蓝）
      tagTextColor: Color(0xFF64B5F6), // 标签文字（浅蓝）
      bottomNavBarColor: Color(0xFF1E1E1E), // 底部导航栏深色
      cardShadowColor: Color(0x1A000000), // 卡片阴影（10% 黑色）
    );
  }

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
    Color? dividerColor,
    Color? shadowColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? inputBackgroundColor,
    Color? inputBorderColor,
    Color? tagBackgroundColor,
    Color? tagTextColor,
    Color? bottomNavBarColor,
    Color? cardShadowColor,
  }) {
    return AppThemeExtension(
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      dividerColor: dividerColor ?? this.dividerColor,
      shadowColor: shadowColor ?? this.shadowColor,
      shimmerBaseColor: shimmerBaseColor ?? this.shimmerBaseColor,
      shimmerHighlightColor:
          shimmerHighlightColor ?? this.shimmerHighlightColor,
      inputBackgroundColor: inputBackgroundColor ?? this.inputBackgroundColor,
      inputBorderColor: inputBorderColor ?? this.inputBorderColor,
      tagBackgroundColor: tagBackgroundColor ?? this.tagBackgroundColor,
      tagTextColor: tagTextColor ?? this.tagTextColor,
      bottomNavBarColor: bottomNavBarColor ?? this.bottomNavBarColor,
      cardShadowColor: cardShadowColor ?? this.cardShadowColor,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      successColor: Color.lerp(successColor, other.successColor, t),
      warningColor: Color.lerp(warningColor, other.warningColor, t),
      infoColor: Color.lerp(infoColor, other.infoColor, t),
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t),
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t),
      shimmerBaseColor: Color.lerp(shimmerBaseColor, other.shimmerBaseColor, t),
      shimmerHighlightColor: Color.lerp(
        shimmerHighlightColor,
        other.shimmerHighlightColor,
        t,
      ),
      inputBackgroundColor: Color.lerp(
        inputBackgroundColor,
        other.inputBackgroundColor,
        t,
      ),
      inputBorderColor: Color.lerp(inputBorderColor, other.inputBorderColor, t),
      tagBackgroundColor: Color.lerp(
        tagBackgroundColor,
        other.tagBackgroundColor,
        t,
      ),
      tagTextColor: Color.lerp(tagTextColor, other.tagTextColor, t),
      bottomNavBarColor: Color.lerp(
        bottomNavBarColor,
        other.bottomNavBarColor,
        t,
      ),
      cardShadowColor: Color.lerp(cardShadowColor, other.cardShadowColor, t),
    );
  }
}

/// 便捷扩展方法，方便在代码中快速获取自定义主题
extension AppThemeExtensionGetter on BuildContext {
  AppThemeExtension get appTheme {
    return Theme.of(this).extension<AppThemeExtension>() ??
        AppThemeExtension.light();
  }
}
