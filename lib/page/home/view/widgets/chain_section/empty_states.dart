part of '../chain_section.dart';

class _NoAssetResults extends StatelessWidget {
  const _NoAssetResults();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: homePanelDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 30.w,
            color: colorScheme.primary,
          ),
          SizedBox(height: 8.h),
          Text(
            S.of(context).assetFilterNoResults,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// 首次加载或链下无资产数据时的占位状态。
class _EmptyBalancePlaceholder extends StatelessWidget {
  const _EmptyBalancePlaceholder({required this.isLoading});

  /// true 表示仍在加载，false 表示加载完成但没有可展示资产。
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        isLoading ? S.of(context).loading : '--',
        style: TextStyle(
          fontSize: 12.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
