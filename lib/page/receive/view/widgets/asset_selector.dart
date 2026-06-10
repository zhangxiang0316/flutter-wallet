import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_asset.dart';
import 'receive_styles.dart';

/// 币种选择器。
///
/// 展示当前链默认资产和用户自定义资产，点击后更新二维码标题和上下文。
class ReceiveAssetSelector extends StatelessWidget {
  const ReceiveAssetSelector({
    super.key,
    required this.assets,
    required this.selectedAsset,
    required this.isLoading,
    required this.onSelected,
  });

  /// 当前链下可选资产列表。
  final List<WalletAsset> assets;

  /// 当前选中的资产。
  final WalletAsset selectedAsset;

  /// 自定义资产是否仍在加载中。
  final bool isLoading;

  /// 用户选择资产后的回调。
  final ValueChanged<WalletAsset> onSelected;

  @override
  Widget build(BuildContext context) {
    return ReceivePanel(
      title: S.of(context).selectReceiveAsset,
      trailing: isLoading
          ? SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(strokeWidth: 2.w),
            )
          : null,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: assets
            .map((asset) {
              final selected = asset.assetKey == selectedAsset.assetKey;
              final color = receiveChainColor(asset.chain);
              return Material(
                color: selected
                    ? color.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8.r),
                child: InkWell(
                  onTap: () => onSelected(asset),
                  borderRadius: BorderRadius.circular(8.r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: BoxConstraints(minHeight: 40.h),
                    padding: EdgeInsets.fromLTRB(9.w, 7.h, 11.w, 7.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: 0.42)
                            : receiveDividerColor(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ReceiveAssetAvatar(
                          symbol: asset.symbol,
                          color: color,
                          size: 24,
                        ),
                        SizedBox(width: 7.w),
                        Text(
                          asset.symbol,
                          style: TextStyle(
                            color: selected
                                ? color
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.78),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}
