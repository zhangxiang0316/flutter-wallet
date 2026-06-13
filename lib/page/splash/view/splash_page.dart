import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../onboarding/view/onboarding_page.dart';

/// Flutter 首屏欢迎页。
///
/// 原生启动屏只能短暂展示静态图片；这里在 Flutter 渲染完成后补一段品牌入场动画，
/// 让用户从白屏/静态 logo 更自然地过渡到首页。
@GetXRoutePage('/splash')
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  /// 整体入场动画：控制 logo、标题和底部进度条依次出现。
  late final AnimationController _introController;

  /// 循环呼吸动画：控制 logo 轻微浮动和背景光环扩散。
  late final AnimationController _pulseController;

  /// logo 的缩放曲线，启动时从略小状态放大到正常大小。
  late final Animation<double> _logoScale;

  /// logo 与文字的透明度曲线。
  late final Animation<double> _fadeIn;

  /// 标题上移动画，避免欢迎页只是一张居中的静态图。
  late final Animation<Offset> _titleOffset;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..forward();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0, 0.62, curve: Curves.easeOutBack),
      ),
    );
    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.08, 0.72, curve: Curves.easeOut),
    );
    _titleOffset = Tween<Offset>(begin: const Offset(0, 0.24), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.38, 0.86, curve: Curves.easeOutCubic),
          ),
        );

    _openHomeAfterAnimation();
  }

  /// 动画播放完成后进入主页面。
  ///
  /// 首次启动显示引导页，非首次直接进入主页。
  Future<void> _openHomeAfterAnimation() async {
    await Future<void>.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      // 首次启动，显示引导页
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OnboardingPage(
            onComplete: () async {
              await prefs.setBool('hasSeenOnboarding', true);
              if (context.mounted) {
                Get.offAllNamed(RouteTable.main);
              }
            },
          ),
        ),
      );
    } else {
      // 非首次启动，直接进入主页
      Get.offAllNamed(RouteTable.main);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SplashHaloPainter(
                    progress: _pulseController.value,
                    color: colorScheme.primary,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  Center(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: _AnimatedLogo(controller: _pulseController),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _titleOffset,
                      child: Column(
                        children: [
                          Text(
                            S.of(context).appName,
                            style: TextStyle(
                              fontSize: 24.sp,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF172033),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            S.of(context).splashTagline,
                            style: TextStyle(
                              fontSize: 12.sp,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF7A8496),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: _SplashProgress(controller: _pulseController),
                  ),
                  SizedBox(height: 38.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 带呼吸浮动的 logo 容器。
///
/// 外层用阴影和轻微上下位移增加层次，内部继续使用现有应用 logo 资产。
class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({required this.controller});

  /// 循环动画控制器，驱动 logo 的轻微浮动。
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Image.asset(
          'assets/icons/logo.png',
          width: 86.w,
          height: 86.w,
          fit: BoxFit.cover,
        ),
      ),
      builder: (context, child) {
        final dy = math.sin(controller.value * math.pi * 2) * 4.h;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 116.w,
            height: 116.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34.r),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 34.r,
                  offset: Offset(0, 18.h),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 底部短进度条。
///
/// 不显示百分比，只用一段循环高亮提示应用正在进入首页，避免启动页显得生硬。
class _SplashProgress extends StatelessWidget {
  const _SplashProgress({required this.controller});

  /// 循环动画控制器，驱动进度条高亮块横向移动。
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 108.w,
          height: 4.h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final progress = Curves.easeInOut.transform(controller.value);
                  return Align(
                    alignment: Alignment(-1 + progress * 2, 0),
                    child: child,
                  );
                },
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999.r),
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          S.of(context).splashLoading,
          style: TextStyle(
            fontSize: 11.sp,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8D96A8),
          ),
        ),
      ],
    );
  }
}

/// 欢迎页背景光环绘制器。
///
/// 绘制在 logo 附近的两层扩散圆环和顶部轻量色块，成本低且不依赖额外资源。
class _SplashHaloPainter extends CustomPainter {
  const _SplashHaloPainter({required this.progress, required this.color});

  /// 当前循环进度，取值 0 到 1。
  final double progress;

  /// 光环基准颜色，跟随当前主题主色。
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.39);
    final baseRadius = math.min(size.width, size.height) * 0.17;

    final topPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [color.withValues(alpha: 0.13), color.withValues(alpha: 0)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.12),
              radius: size.width * 0.58,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.12),
      size.width * 0.58,
      topPaint,
    );

    for (var i = 0; i < 2; i++) {
      final ringProgress = (progress + i * 0.5) % 1;
      final opacity = (1 - ringProgress).clamp(0.0, 1.0) * 0.16;
      final radius = baseRadius + ringProgress * 64;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, ringPaint);
    }

    final dotPaint = Paint()..color = color.withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.31),
      4,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.48),
      5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashHaloPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
