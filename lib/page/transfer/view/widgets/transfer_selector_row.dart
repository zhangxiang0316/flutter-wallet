import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'transfer_styles.dart';

/// 转账网络和币种的组合选择区。
///
/// 与收款页保持一致，用户可以在转账页面内直接切换当前钱包地址所属网络和
/// 当前网络下的可转出币种。切换结果由控制器同步到余额展示、地址校验、
/// 手续费估算和最终提交参数。
class TransferSelectorRow extends StatelessWidget {
  const TransferSelectorRow({
    super.key,
    required this.chains,
    required this.selectedAsset,
    required this.assets,
    required this.isEnabled,
    required this.onChainSelected,
    required this.onAssetSelected,
  });

  /// 当前可选择的转账网络。
  final List<WalletChainConfig> chains;

  /// 当前选中的转账资产。
  final ChainBalance selectedAsset;

  /// 当前网络下可选择的转账资产。
  final List<ChainBalance> assets;

  /// 表单是否可操作，提交交易时会禁用。
  final bool isEnabled;

  /// 用户切换转账网络后的回调。
  final ValueChanged<WalletChainConfig> onChainSelected;

  /// 用户切换转账币种后的回调。
  final ValueChanged<ChainBalance> onAssetSelected;

  @override
  Widget build(BuildContext context) {
    final chainColor = transferChainColor(selectedAsset.chainRef);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: transferPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _ChainDropdown(
                  chains: chains,
                  selectedChain:
                      selectedAsset.chainConfig ?? selectedAsset.chain!.config,
                  isEnabled: isEnabled,
                  onChanged: onChainSelected,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _AssetDropdown(
                  assets: assets,
                  selectedAsset: selectedAsset,
                  isEnabled: isEnabled,
                  onChanged: onAssetSelected,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _FromAddressBox(
            address: selectedAsset.address,
            chainColor: chainColor,
            isEnabled: isEnabled,
          ),
        ],
      ),
    );
  }
}

/// 转账网络下拉框。
class _ChainDropdown extends StatelessWidget {
  const _ChainDropdown({
    required this.chains,
    required this.selectedChain,
    required this.isEnabled,
    required this.onChanged,
  });

  /// 可选网络。
  final List<WalletChainConfig> chains;

  /// 当前选中的网络。
  final WalletChainConfig selectedChain;

  /// 是否允许选择。
  final bool isEnabled;

  /// 网络切换回调。
  final ValueChanged<WalletChainConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    // 如果 chains 为空，返回禁用的下拉框
    if (chains.isEmpty) {
      return DropdownButtonFormField<WalletChainConfig>(
        decoration: _dropdownDecoration(
          context,
          label: S.of(context).selectTransferChain,
          focusColor: Colors.grey,
        ),
        items: const [],
        onChanged: null,
      );
    }

    // 使用对象相等性比较（而不是 ID）来查找 selectedChain
    final validSelectedChain = chains.firstWhere(
      (c) => c.id == selectedChain.id,
      orElse: () => chains.first,
    );

    return DropdownButtonFormField<WalletChainConfig>(
      key: ValueKey(validSelectedChain.id),
      value: validSelectedChain, // 使用 value 而不是 initialValue
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.w),
      decoration: _dropdownDecoration(
        context,
        label: S.of(context).selectTransferChain,
        focusColor: transferChainColor(validSelectedChain),
      ),
      borderRadius: BorderRadius.circular(8.r),
      dropdownColor: Theme.of(context).cardColor,
      items: chains
          .map((chain) {
            return DropdownMenuItem<WalletChainConfig>(
              value: chain,
              child: _ChainOption(
                chain: chain,
                selected: chain.id == validSelectedChain.id,
              ),
            );
          })
          .toList(growable: false),
      selectedItemBuilder: (context) {
        return chains
            .map((chain) {
              return _ChainOption(chain: chain, selected: true);
            })
            .toList(growable: false);
      },
      onChanged: isEnabled
          ? (chain) {
              if (chain == null) return;
              onChanged(chain);
            }
          : null,
    );
  }
}

/// 转账币种下拉框。
class _AssetDropdown extends StatelessWidget {
  const _AssetDropdown({
    required this.assets,
    required this.selectedAsset,
    required this.isEnabled,
    required this.onChanged,
  });

  /// 当前链下可选资产。
  final List<ChainBalance> assets;

  /// 当前选中的资产。
  final ChainBalance selectedAsset;

  /// 是否允许选择。
  final bool isEnabled;

  /// 资产切换回调。
  final ValueChanged<ChainBalance> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedKey =
        assets.any((asset) => _assetKey(asset) == _assetKey(selectedAsset))
        ? _assetKey(selectedAsset)
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${selectedAsset.chainId}:$selectedKey'),
      initialValue: selectedKey,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.w),
      decoration: _dropdownDecoration(
        context,
        label: S.of(context).selectTransferAsset,
        focusColor: transferChainColor(selectedAsset.chainRef),
      ),
      borderRadius: BorderRadius.circular(8.r),
      dropdownColor: Theme.of(context).cardColor,
      items: assets
          .map((asset) {
            return DropdownMenuItem<String>(
              value: _assetKey(asset),
              child: _AssetOption(asset: asset),
            );
          })
          .toList(growable: false),
      onChanged: isEnabled
          ? (assetKey) {
              if (assetKey == null) return;
              final selected = assets.firstWhere(
                (asset) => _assetKey(asset) == assetKey,
                orElse: () => selectedAsset,
              );
              onChanged(selected);
            }
          : null,
    );
  }
}

/// 单个网络选项的展示样式。
class _ChainOption extends StatelessWidget {
  const _ChainOption({required this.chain, required this.selected});

  /// 对应网络。
  final WalletChainConfig chain;

  /// 是否为当前选中项。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = transferChainColor(chain);
    return Row(
      children: [
        Container(
          width: 20.w,
          height: 20.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            chain.symbol.characters.first,
            style: TextStyle(
              color: color,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 7.w),
        Expanded(
          child: Text(
            chain.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

/// 单个资产选项的展示样式。
class _AssetOption extends StatelessWidget {
  const _AssetOption({required this.asset});

  /// 对应资产。
  final ChainBalance asset;

  @override
  Widget build(BuildContext context) {
    final color = transferAssetColor(context, asset.symbol);
    return Row(
      children: [
        Container(
          width: 22.w,
          height: 22.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7.r),
          ),
          child: Text(
            asset.symbol.characters.first.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 7.w),
        Expanded(
          child: Text(
            asset.symbol,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

/// 当前链钱包地址展示区。
class _FromAddressBox extends StatelessWidget {
  const _FromAddressBox({
    required this.address,
    required this.chainColor,
    required this.isEnabled,
  });

  /// 当前链对应的钱包地址。
  final String address;

  /// 当前链强调色。
  final Color chainColor;

  /// 是否允许复制。
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: context.appTheme.dividerColor!.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chainColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: chainColor,
              size: 17.w,
            ),
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).transferFromAddress,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  hasAddress ? address : S.of(context).receiveAddressEmpty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.of(context).copyWalletAddress,
            visualDensity: VisualDensity.compact,
            onPressed: hasAddress && isEnabled
                ? () {
                    Clipboard.setData(ClipboardData(text: address));
                    Toast.show(S.current.copied);
                  }
                : null,
            icon: Icon(Icons.copy_rounded, size: 17.w),
          ),
        ],
      ),
    );
  }
}

/// 转账选择区统一的下拉输入框样式。
InputDecoration _dropdownDecoration(
  BuildContext context, {
  required String label,
  required Color focusColor,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
    filled: true,
    fillColor: colorScheme.onSurface.withValues(alpha: 0.035),
    labelStyle: TextStyle(
      color: colorScheme.onSurface.withValues(alpha: 0.56),
      fontSize: 10.5.sp,
      fontWeight: FontWeight.w700,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(
        color: context.appTheme.dividerColor!.withValues(alpha: 0.58),
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(
        color: context.appTheme.dividerColor!.withValues(alpha: 0.38),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: focusColor.withValues(alpha: 0.58)),
    ),
  );
}

/// 构建转账资产唯一 key。
String _assetKey(ChainBalance asset) {
  final contract = asset.contractAddress?.trim() ?? '';
  final normalizedContract = asset.chainRef.isEvm
      ? contract.toLowerCase()
      : contract;
  return [
    asset.chainId,
    normalizedContract.isEmpty ? 'native' : normalizedContract,
    asset.symbol.toUpperCase(),
  ].join(':');
}
