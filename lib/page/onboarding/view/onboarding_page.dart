import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../generated/l10n.dart';

/// 首次启动引导页面。
///
/// 通过滑动卡片介绍应用核心功能和安全特性。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  /// 完成引导后的回调。
  final VoidCallback onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [];

  @override
  void initState() {
    super.initState();
    // 延迟初始化，等待 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _pages.addAll([
            OnboardingData(
              icon: Icons.account_balance_wallet,
              iconColor: const Color(0xFF8B5CF6),
              title: S.of(context).onboardingTitle1,
              description: S.of(context).onboardingDesc1,
            ),
            OnboardingData(
              icon: Icons.security,
              iconColor: const Color(0xFF3B82F6),
              title: S.of(context).onboardingTitle2,
              description: S.of(context).onboardingDesc2,
            ),
            OnboardingData(
              icon: Icons.fingerprint,
              iconColor: const Color(0xFF06B6D4),
              title: S.of(context).onboardingTitle3,
              description: S.of(context).onboardingDesc3,
            ),
            OnboardingData(
              icon: Icons.bolt,
              iconColor: const Color(0xFFEC4899),
              title: S.of(context).onboardingTitle4,
              description: S.of(context).onboardingDesc4,
            ),
          ]);
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            if (!isLastPage)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: Text(
                    S.of(context).skip,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ).marginOnly(right: 8.w, top: 8.h),
              )
            else
              SizedBox(height: 56.h),

            // 页面内容
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingSlide(data: _pages[index]);
                },
              ),
            ),

            // 指示器
            SizedBox(
              height: 80.h,
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _pages.length,
                    effect: WormEffect(
                      dotWidth: 8.w,
                      dotHeight: 8.h,
                      activeDotColor: Theme.of(context).colorScheme.primary,
                      dotColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  // 按钮
                  SizedBox(
                    width: 280.w,
                    height: 48.h,
                    child: FilledButton(
                      onPressed: () {
                        if (isLastPage) {
                          widget.onComplete();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        isLastPage
                            ? S.of(context).getStarted
                            : S.of(context).next,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).marginOnly(bottom: 32.h),
          ],
        ),
      ),
    );
  }
}

/// 单个引导页数据。
class OnboardingData {
  const OnboardingData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
}

/// 单个引导页滑片。
class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              color: data.iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 60.w,
              color: data.iconColor,
            ),
          ),
          SizedBox(height: 48.h),

          // 标题
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.3,
            ),
          ),
          SizedBox(height: 16.h),

          // 描述
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
