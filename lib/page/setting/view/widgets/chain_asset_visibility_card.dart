import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_asset.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'asset_visibility_styles.dart';

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

  final WalletChain chain;
  final List<WalletAsset> assets;
  final bool Function(WalletAsset asset) isVisible;
  final Future<void> Function(WalletAsset asset, bool visible) onChanged;
  final VoidCallback onAddPressed;
  final Future<void> Function(WalletAsset asset) onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                    fontSize: 12.sp,
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
                    fontSize: 14.sp,
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

  Color _chainColor(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return const Color(0xFFF0B90B);
      case WalletChain.ethereum:
        return const Color(0xFF627EEA);
      case WalletChain.xLayer:
        return const Color(0xFF111827);
      case WalletChain.solana:
        return const Color(0xFF14F195);
      case WalletChain.tron:
        return const Color(0xFFE50914);
    }
  }
}

class _AssetVisibilityTile extends StatelessWidget {
  const _AssetVisibilityTile({
    required this.asset,
    required this.visible,
    required this.onChanged,
    this.onRemovePressed,
  });

  final WalletAsset asset;
  final bool visible;
  final ValueChanged<bool> onChanged;
  final Future<void> Function()? onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              asset.symbol.trim().isEmpty ? '?' : asset.symbol.characters.first,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
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
                    fontSize: 12.5.sp,
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
                    fontSize: 10.5.sp,
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

Future<bool> _confirmRemoveCustomAsset(
  BuildContext context,
  WalletAsset asset,
) async {
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
