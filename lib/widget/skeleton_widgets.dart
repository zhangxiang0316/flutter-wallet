import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// 通用骨架屏容器。
///
/// 提供统一的 Shimmer 效果，用于构建各种骨架屏组件。
class SkeletonContainer extends StatelessWidget {
  const SkeletonContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 4.0,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// 钱包资产概览卡片骨架屏。
///
/// 用于首页顶部总资产卡片的加载状态。
class WalletOverviewSkeleton extends StatelessWidget {
  const WalletOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 钱包名称
          Row(
            children: [
              SkeletonContainer(
                width: 24.w,
                height: 24.w,
                borderRadius: 12.w,
              ),
              SizedBox(width: 8.w),
              SkeletonContainer(width: 100.w, height: 16.h),
              const Spacer(),
              SkeletonContainer(width: 60.w, height: 28.h, borderRadius: 14.h),
            ],
          ),
          SizedBox(height: 20.h),
          // 总资产标签
          SkeletonContainer(width: 80.w, height: 14.h),
          SizedBox(height: 8.h),
          // 总资产金额
          SkeletonContainer(width: 180.w, height: 32.h),
          SizedBox(height: 24.h),
          // 收款/转账按钮
          Row(
            children: [
              Expanded(
                child: SkeletonContainer(
                  height: 44.h,
                  borderRadius: 8.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SkeletonContainer(
                  height: 44.h,
                  borderRadius: 8.r,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 链资产项骨架屏。
///
/// 用于链资产列表的加载状态。
class ChainBalanceItemSkeleton extends StatelessWidget {
  const ChainBalanceItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Row(
        children: [
          // 代币图标
          SkeletonContainer(
            width: 40.w,
            height: 40.w,
            borderRadius: 20.w,
          ),
          SizedBox(width: 12.w),
          // 代币信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer(width: 100.w, height: 14.h),
                SizedBox(height: 6.h),
                SkeletonContainer(width: 60.w, height: 12.h),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // 余额
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonContainer(width: 80.w, height: 14.h),
              SizedBox(height: 6.h),
              SkeletonContainer(width: 60.w, height: 12.h),
            ],
          ),
        ],
      ),
    );
  }
}

/// 链卡片骨架屏。
///
/// 用于首页链卡片的加载状态。
class ChainCardSkeleton extends StatelessWidget {
  const ChainCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // 链图标
          SkeletonContainer(
            width: 32.w,
            height: 32.w,
            borderRadius: 16.w,
          ),
          SizedBox(width: 12.w),
          // 链名称
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer(width: 80.w, height: 14.h),
                SizedBox(height: 6.h),
                SkeletonContainer(width: 50.w, height: 12.h),
              ],
            ),
          ),
          // USD 值
          SkeletonContainer(width: 60.w, height: 16.h),
        ],
      ),
    );
  }
}

/// 链资产列表骨架屏。
///
/// 展示多个链资产项的加载状态。
class ChainBalanceListSkeleton extends StatelessWidget {
  const ChainBalanceListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ChainBalanceItemSkeleton(),
    );
  }
}
