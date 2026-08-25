import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_asset.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'receive_styles.dart';

/// 收款网络和币种的组合选择区。
///
/// 两个下拉框放在同一行，先选择网络，再选择当前网络下的币种。
///
/// 网络下拉值使用链 id，币种下拉值使用 [WalletAsset.assetKey]，避免配置重新加载后
/// 因为对象引用变化导致选中项失效。
class ReceiveSelectorRow extends StatelessWidget {
  const ReceiveSelectorRow({
    super.key,
    required this.chains,
    required this.selectedChain,
    required this.assets,
    required this.selectedAsset,
    required this.isLoading,
    required this.onChainSelected,
    required this.onAssetSelected,
  });

  /// 当前选中的收款网络。
  final WalletChainConfig selectedChain;

  /// 当前可用的收款网络列表。
  final List<WalletChainConfig> chains;

  /// 当前网络下可选的收款币种。
  final List<WalletAsset> assets;

  /// 当前选中的收款币种。
  final WalletAsset selectedAsset;

  /// 是否正在加载用户自定义币种。
  final bool isLoading;

  /// 用户切换网络后的回调。
  final ValueChanged<WalletChainConfig> onChainSelected;

  /// 用户切换币种后的回调。
  final ValueChanged<WalletAsset> onAssetSelected;

  @override
  Widget build(BuildContext context) {
    return ReceivePanel(
      title: S.of(context).receive,
      trailing: isLoading
          ? SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(strokeWidth: 2.w),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: _ChainDropdown(
              chains: chains,
              selectedChain: selectedChain,
              onChanged: onChainSelected,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _AssetDropdown(
              assets: assets,
              selectedAsset: selectedAsset,
              onChanged: onAssetSelected,
            ),
          ),
        ],
      ),
    );
  }
}

/// 网络下拉框。
class _ChainDropdown extends StatelessWidget {
  const _ChainDropdown({
    required this.chains,
    required this.selectedChain,
    required this.onChanged,
  });

  /// 当前选中的网络。
  final WalletChainConfig selectedChain;

  /// 可选网络列表。
  final List<WalletChainConfig> chains;

  /// 网络切换回调。
  final ValueChanged<WalletChainConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final uniqueChains = _uniqueChainsById(chains);
    final selectedChainId =
        uniqueChains.any((chain) => chain.id == selectedChain.id)
        ? selectedChain.id
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('chain:$selectedChainId'),
      initialValue: selectedChainId,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.w),
      decoration: _dropdownDecoration(
        context,
        label: S.of(context).selectReceiveChain,
        focusColor: receiveChainColor(context, selectedChain),
      ),
      borderRadius: BorderRadius.circular(8.r),
      dropdownColor: Theme.of(context).cardColor,
      items: uniqueChains
          .map((chain) {
            return DropdownMenuItem<String>(
              value: chain.id,
              child: Row(
                children: [
                  ReceiveChainDot(
                    chain: chain,
                    selected: chain.id == selectedChain.id,
                  ),
                  SizedBox(width: 7.w),
                  Expanded(
                    child: Text(
                      chain.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
      selectedItemBuilder: (context) {
        return uniqueChains
            .map((chain) {
              return Row(
                children: [
                  ReceiveChainDot(chain: chain, selected: true),
                  SizedBox(width: 7.w),
                  Expanded(
                    child: Text(
                      chain.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            })
            .toList(growable: false);
      },
      onChanged: (chainId) {
        if (chainId == null) return;
        final selected = uniqueChains.firstWhere(
          (chain) => chain.id == chainId,
          orElse: () => selectedChain,
        );
        onChanged(selected);
      },
    );
  }
}

/// 币种下拉框。
class _AssetDropdown extends StatelessWidget {
  const _AssetDropdown({
    required this.assets,
    required this.selectedAsset,
    required this.onChanged,
  });

  /// 当前网络下可选币种。
  final List<WalletAsset> assets;

  /// 当前选中的币种。
  final WalletAsset selectedAsset;

  /// 币种切换回调。
  final ValueChanged<WalletAsset> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedKey =
        assets.any((asset) => asset.assetKey == selectedAsset.assetKey)
        ? selectedAsset.assetKey
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${selectedAsset.chainId}:$selectedKey'),
      initialValue: selectedKey,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.w),
      decoration: _dropdownDecoration(
        context,
        label: S.of(context).selectReceiveAsset,
        focusColor: receiveChainColor(context, selectedAsset.chainRef),
      ),
      borderRadius: BorderRadius.circular(8.r),
      dropdownColor: Theme.of(context).cardColor,
      items: assets
          .map((asset) {
            final color = receiveChainColor(context, asset.chainRef);
            return DropdownMenuItem<String>(
              value: asset.assetKey,
              child: Row(
                children: [
                  ReceiveAssetAvatar(
                    symbol: asset.symbol,
                    color: color,
                    size: 22,
                  ),
                  SizedBox(width: 7.w),
                  Expanded(
                    child: Text(
                      asset.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
      onChanged: (assetKey) {
        if (assetKey == null) return;
        final selected = assets.firstWhere(
          (asset) => asset.assetKey == assetKey,
          orElse: () => selectedAsset,
        );
        onChanged(selected);
      },
    );
  }
}

/// 收款选择区统一的下拉输入框样式。
InputDecoration _dropdownDecoration(
  BuildContext context, {
  required String label,
  required Color focusColor,
}) {
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
    filled: true,
    fillColor: Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface
        : const Color(0xFFF7F8FA),
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.56),
      fontSize: 11.sp,
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: receiveDividerColor(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: focusColor.withValues(alpha: 0.48)),
    ),
  );
}

List<WalletChainConfig> _uniqueChainsById(List<WalletChainConfig> chains) {
  final seenIds = <String>{};
  final uniqueChains = <WalletChainConfig>[];
  for (final chain in chains) {
    if (seenIds.add(chain.id)) {
      uniqueChains.add(chain);
    }
  }
  return uniqueChains;
}
