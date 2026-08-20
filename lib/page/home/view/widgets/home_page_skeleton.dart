import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../widget/skeleton_widgets.dart';
import 'home_styles.dart';

/// 首页代币资产区域加载骨架屏。
///
/// 钱包卡片和安全提示不依赖网络，会立即展示；只有尚无缓存的资产列表使用
/// 一个共享 Shimmer 动画，减少首屏动画控制器和重绘开销。
class HomeTokenPortfolioSkeleton extends StatelessWidget {
  const HomeTokenPortfolioSkeleton({super.key, this.assetRowCount = 4});

  /// 代币资产面板里占位行的数量。
  final int assetRowCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            child: SkeletonContainer(width: 90.w, height: 16.h),
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: homePanelDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < assetRowCount; i++) ...[
                  const _AssetRowSkeleton(),
                  if (i != assetRowCount - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 58.w,
                      color: homeDividerColor(context),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 代币资产列表里每一行的骨架占位。
class _AssetRowSkeleton extends StatelessWidget {
  const _AssetRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Row(
        children: [
          // 代币图标
          SkeletonContainer(width: 36.w, height: 36.w, borderRadius: 9.r),
          SizedBox(width: 10.w),
          // 代币名称与网络
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer(width: 80.w, height: 13.h),
                SizedBox(height: 6.h),
                SkeletonContainer(width: 56.w, height: 11.h),
              ],
            ),
          ),
          // 数量与 USD 值
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonContainer(width: 72.w, height: 12.h),
              SizedBox(height: 6.h),
              SkeletonContainer(width: 52.w, height: 10.h),
            ],
          ),
          SizedBox(width: 3.w),
          SkeletonContainer(width: 16.w, height: 16.h, borderRadius: 8.w),
        ],
      ),
    );
  }
}
