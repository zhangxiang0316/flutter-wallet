import 'package:flutter/material.dart';

/// 首页统一背景容器。
///
/// 浅色模式使用接近 Vant 的页面灰底，深色模式沿用全局 Scaffold 背景色，
/// 让首页里的卡片、弹窗入口和资产列表保持一致的页面基底。
class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.child});

  /// 首页实际内容，一般是可滚动的钱包概览和链资产列表。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 深色模式不额外叠加浅灰背景，避免影响全局暗色主题层级。
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: child,
    );
  }
}
