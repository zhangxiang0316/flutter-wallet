import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../widget/skeleton_widgets.dart';
import 'home_styles.dart';

/// 首页整体加载骨架屏。
///
/// 首次进入首页且本地还没有可展示的余额/资产数据时，用它铺满页面主体，
/// 让用户感知页面结构，避免整屏空白或只显示一圈微小的 load 指示器。
/// 布局与首页真实内容保持对齐：顶部钱包资产 Hero 卡、代币资产面板和底部
/// 私钥安全提示。
class HomePageSkeleton extends StatelessWidget {
  const HomePageSkeleton({super.key, this.assetRowCount = 4});

  /// 代币资产面板里占位行的数量。
  final int assetRowCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroSkeleton(),
        SizedBox(height: 16.h),
        // 代币资产标题占位
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
        SizedBox(height: 16.h),
        const _PrivateKeyNoticeSkeleton(),
      ],
    );
  }
}

/// 顶部钱包资产 Hero 卡的骨架占位。
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 20.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: homeDividerColor(context)),
      ),
      child: Column(
        children: [
          // 钱包名称胶囊
          Align(
            alignment: Alignment.centerLeft,
            child: SkeletonContainer(
              width: 140.w,
              height: 34.h,
              borderRadius: 17.h,
            ),
          ),
          SizedBox(height: 18.h),
          // 总资产标签
          Align(
            alignment: Alignment.center,
            child: SkeletonContainer(
              width: 96.w,
              height: 20.h,
              borderRadius: 10.h,
            ),
          ),
          SizedBox(height: 10.h),
          // 总资产金额
          Align(
            alignment: Alignment.center,
            child: SkeletonContainer(
              width: 180.w,
              height: 36.h,
              borderRadius: 8.r,
            ),
          ),
          SizedBox(height: 18.h),
          // 收款 / 转账按钮
          Row(
            children: [
              Expanded(
                child: SkeletonContainer(
                  height: 38.h,
                  borderRadius: 999.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: SkeletonContainer(
                  height: 38.h,
                  borderRadius: 999.r,
                ),
              ),
            ],
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
          SkeletonContainer(
            width: 36.w,
            height: 36.w,
            borderRadius: 9.r,
          ),
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

/// 首页底部私钥安全提示的骨架占位。
class _PrivateKeyNoticeSkeleton extends StatelessWidget {
  const _PrivateKeyNoticeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: homePanelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonContainer(
            width: 30.w,
            height: 30.w,
            borderRadius: 8.r,
          ).marginOnly(right: 9.w, top: 1.h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonContainer(width: 90.w, height: 12.h),
                SizedBox(height: 7.h),
                SkeletonContainer(width: 220.w, height: 11.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}