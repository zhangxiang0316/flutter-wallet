import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_asset.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'asset_visibility_styles.dart';

/// 单条链的资产显示设置卡片。
///
/// 卡片头部展示链信息和添加自定义资产入口，下方逐个展示该链资产的显示开关。
class ChainAssetVisibilityCard extends StatelessWidget {
  const ChainAssetVisibilityCard({
    super.key,
    required this.chain,
    required this.assets,
    required this.isVisible,
    required this.onChanged,
    required this.onAddPressed,
    required this.onRemovePressed,
  });

  /// 当前卡片对应的链。
  final WalletChainConfig chain;

  /// 当前链下默认资产和自定义资产合并后的列表。
  final List<WalletAsset> assets;

  /// 判断资产当前是否在首页展示。
  final bool Function(WalletAsset asset) isVisible;

  /// 切换资产显示/隐藏状态后的回调。
  final Future<void> Function(WalletAsset asset, bool visible) onChanged;

  /// 点击链标题右侧加号后的回调。
  final VoidCallback onAddPressed;

  /// 用户确认移除自定义资产后的回调。
  final Future<void> Function(WalletAsset asset) onRemovePressed;

  @override
  Widget build(BuildContext context) {
    // 当前主题色用于文字和添加按钮。
    final colorScheme = Theme.of(context).colorScheme;

    // 当前链品牌色用于链头像。
    final chainColor = _chainColor(chain);
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
      decoration: assetVisibilityPanelDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  chain.symbol.characters.first,
                  style: TextStyle(
                    color: chainColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  chain.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tight(Size(32.w, 32.w)),
                padding: EdgeInsets.zero,
                onPressed: onAddPressed,
                icon: Icon(
                  Icons.add_rounded,
                  size: 20.w,
                  color: colorScheme.primary,
                ),
                tooltip: S.of(context).addCustomAsset,
              ),
            ],
          ).marginOnly(bottom: 8.h),
          ...assets.map(
            (asset) => _AssetVisibilityTile(
              asset: asset,
              visible: isVisible(asset),
              onChanged: (visible) => onChanged(asset, visible),
              onRemovePressed: asset.isCustom
                  ? () => onRemovePressed(asset)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取当前链在设置页中的品牌色。
  Color _chainColor(WalletChainConfig chain) {
    if (chain.colorValue != null) {
      return Color(chain.colorValue!);
    }
    switch (chain.builtinChain) {
      case WalletChain.bsc:
        return const Color(0xFFF0B90B);
      case WalletChain.ethereum:
        return const Color(0xFF627EEA);
      case WalletChain.xLayer:
        return const Color(0xFF111827);
      case WalletChain.arbitrum:
        return const Color(0xFF28A0F0);
      case WalletChain.solana:
        return const Color(0xFF14F195);
      case WalletChain.tron:
        return const Color(0xFFE50914);
      case null:
        return const Color(0xFF2563EB);
    }
  }
}

/// 单个资产的显示设置行。
///
/// 默认资产只展示开关，自定义资产额外展示删除按钮。
class _AssetVisibilityTile extends StatelessWidget {
  const _AssetVisibilityTile({
    required this.asset,
    required this.visible,
    required this.onChanged,
    this.onRemovePressed,
  });

  /// 当前行对应的资产。
  final WalletAsset asset;

  /// 当前资产是否在首页展示。
  final bool visible;

  /// 切换开关后的回调。
  final ValueChanged<bool> onChanged;

  /// 删除自定义资产的回调；为空表示这是默认资产，不允许删除。
  final Future<void> Function()? onRemovePressed;

  @override
  Widget build(BuildContext context) {
    // 当前主题色用于资产头像、说明文字和删除按钮。
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          _AssetLogo(asset: asset, size: 30.w, colorScheme: colorScheme),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (onRemovePressed != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tight(Size(32.w, 32.w)),
              padding: EdgeInsets.zero,
              onPressed: () async {
                // 自定义资产删除前需要二次确认，避免误删。
                final shouldRemove = await _confirmRemoveCustomAsset(
                  context,
                  asset,
                );
                if (shouldRemove) {
                  await onRemovePressed?.call();
                }
              },
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18.w,
                color: colorScheme.error.withValues(alpha: 0.78),
              ),
              tooltip: S.of(context).removeCustomAsset,
            ),
          Switch.adaptive(value: visible, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({
    required this.asset,
    required this.size,
    required this.colorScheme,
  });

  final WalletAsset asset;
  final double size;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        asset.symbol.trim().isEmpty ? '?' : asset.symbol.characters.first,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 10.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final logoUrl = asset.logoUrl?.trim() ?? '';
    if (logoUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

/// 移除自定义资产前的二次确认弹窗。
Future<bool> _confirmRemoveCustomAsset(
  BuildContext context,
  WalletAsset asset,
) async {
  // 删除确认按钮使用错误色，提示这是高风险操作。
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(S.of(dialogContext).removeCustomAsset),
            content: Text(
              S.of(dialogContext).removeCustomAssetConfirmMessage(asset.symbol),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(S.of(dialogContext).cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(S.of(dialogContext).removeCustomAsset),
              ),
            ],
          );
        },
      ) ??
      false;
}
