import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_asset.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_asset_visibility_service.dart';
import '../../../wallet/services/wallet_custom_asset_service.dart';

@GetXRoutePage('/assetVisibility')
// ignore: use_key_in_widget_constructors, must_be_immutable
class AssetVisibilityPage extends BaseScaffoldPage<AssetVisibilityController> {
  @override
  AssetVisibilityController generateController() {
    return AssetVisibilityController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 50.h,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: Get.back,
      ),
      centerTitle: true,
      title: Text(
        S.of(context!).assetVisibility,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context!).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context!).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  @override
  Widget? getBody() {
    return ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _VisibilityIntroCard(),
          SizedBox(height: 12.h),
          ...WalletChain.values.map(
            (chain) => _ChainAssetVisibilityCard(
              chain: chain,
              assets: controller.assetsForChain(chain),
              isVisible: controller.isAssetVisible,
              onChanged: controller.setAssetVisible,
              onAddPressed: () => _showAddAssetSheet(chain),
              onRemovePressed: controller.removeCustomAsset,
            ).marginOnly(bottom: 12.h),
          ),
        ],
      ),
    );
  }

  void _showAddAssetSheet(WalletChain chain) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AddCustomAssetSheet(
        chain: chain,
        onFetchMetadata: controller.fetchEvmTokenMetadata,
        onSubmit: controller.addCustomAsset,
      ),
    );
  }
}

class _VisibilityIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: _settingPanelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.visibility_outlined,
              size: 18.w,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              S.of(context).assetVisibilityTip,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 12.sp,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChainAssetVisibilityCard extends StatelessWidget {
  const _ChainAssetVisibilityCard({
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
      decoration: _settingPanelDecoration(context),
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

class _AddCustomAssetSheet extends StatefulWidget {
  const _AddCustomAssetSheet({
    required this.chain,
    required this.onFetchMetadata,
    required this.onSubmit,
  });

  final WalletChain chain;
  final Future<WalletAsset?> Function({
    required WalletChain chain,
    required String contractAddress,
  })
  onFetchMetadata;
  final Future<bool> Function({
    required WalletChain chain,
    required String contractAddress,
    required String symbol,
    required String name,
    required int decimals,
  })
  onSubmit;

  @override
  State<_AddCustomAssetSheet> createState() => _AddCustomAssetSheetState();
}

class _AddCustomAssetSheetState extends State<_AddCustomAssetSheet> {
  final TextEditingController _contractController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _decimalsController = TextEditingController();

  bool _isFetching = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contractController.dispose();
    _symbolController.dispose();
    _nameController.dispose();
    _decimalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of(context).addCustomAsset,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        widget.chain.name,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _CustomAssetTextField(
                  controller: _contractController,
                  label: S.of(context).customAssetContractAddress,
                  hint: S.of(context).customAssetContractHint,
                  textInputAction: TextInputAction.next,
                ),
                if (widget.chain.isEvm) ...[
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isFetching ? null : _fetchMetadata,
                      icon: _isFetching
                          ? SizedBox(
                              width: 15.w,
                              height: 15.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(Icons.auto_awesome_rounded, size: 16.w),
                      label: Text(S.of(context).fetchTokenInfo),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 11.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                _CustomAssetTextField(
                  controller: _symbolController,
                  label: S.of(context).customAssetSymbol,
                  hint: 'USDT',
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12.h),
                _CustomAssetTextField(
                  controller: _nameController,
                  label: S.of(context).customAssetName,
                  hint: 'Tether USD',
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12.h),
                _CustomAssetTextField(
                  controller: _decimalsController,
                  label: S.of(context).customAssetDecimals,
                  hint: '18',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 15.w,
                            height: 15.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(Icons.add_rounded, size: 18.w),
                    label: Text(S.of(context).addCustomAsset),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchMetadata() async {
    final contractAddress = _contractController.text.trim();
    if (contractAddress.isEmpty) {
      Toast.show(S.current.customAssetInvalid);
      return;
    }

    setState(() {
      _isFetching = true;
    });
    final metadata = await widget.onFetchMetadata(
      chain: widget.chain,
      contractAddress: contractAddress,
    );
    if (!mounted) return;
    setState(() {
      _isFetching = false;
    });

    if (metadata == null) {
      Toast.show(S.current.customAssetMetadataUnavailable);
      return;
    }
    _contractController.text = metadata.contractAddress ?? contractAddress;
    _symbolController.text = metadata.symbol;
    _nameController.text = metadata.name;
    _decimalsController.text = metadata.decimals.toString();
  }

  Future<void> _submit() async {
    final decimals = int.tryParse(_decimalsController.text.trim());
    if (decimals == null) {
      Toast.show(S.current.customAssetInvalid);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    final success = await widget.onSubmit(
      chain: widget.chain,
      contractAddress: _contractController.text.trim(),
      symbol: _symbolController.text.trim(),
      name: _nameController.text.trim(),
      decimals: decimals,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (success) {
      Toast.show(S.current.customAssetAdded);
      Navigator.of(context).pop();
    }
  }
}

class _CustomAssetTextField extends StatelessWidget {
  const _CustomAssetTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
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

class AssetVisibilityController extends BaseController {
  AssetVisibilityController({
    WalletAssetVisibilityService? service,
    WalletCustomAssetService? customAssetService,
  }) : _service = service ?? WalletAssetVisibilityService(),
       _customAssetService = customAssetService ?? WalletCustomAssetService();

  final WalletAssetVisibilityService _service;
  final WalletCustomAssetService _customAssetService;
  Set<String> hiddenAssetKeys = {};
  List<WalletAsset> customAssets = [];

  @override
  void onInit() {
    super.onInit();
    loadVisibility();
  }

  Future<void> loadVisibility() async {
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    customAssets = await _customAssetService.loadCustomAssets();
    update();
  }

  List<WalletAsset> assetsForChain(WalletChain chain) {
    return WalletAssetRegistry.mergeCustomAssets(chain, customAssets);
  }

  bool isAssetVisible(WalletAsset asset) {
    return !hiddenAssetKeys.contains(_service.keyForAsset(asset));
  }

  Future<void> setAssetVisible(WalletAsset asset, bool visible) async {
    await _service.setAssetVisible(asset: asset, visible: visible);
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    update();
  }

  Future<WalletAsset?> fetchEvmTokenMetadata({
    required WalletChain chain,
    required String contractAddress,
  }) async {
    try {
      return await _customAssetService.fetchEvmTokenMetadata(
        chain: chain,
        contractAddress: contractAddress,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> addCustomAsset({
    required WalletChain chain,
    required String contractAddress,
    required String symbol,
    required String name,
    required int decimals,
  }) async {
    try {
      final asset = _customAssetService.buildManualAsset(
        chain: chain,
        contractAddress: contractAddress,
        symbol: symbol,
        name: name,
        decimals: decimals,
      );
      await _customAssetService.addCustomAsset(asset);
      await _service.setAssetVisible(asset: asset, visible: true);
      await loadVisibility();
      return true;
    } on CustomAssetDuplicateException {
      Toast.show(S.current.customAssetDuplicate);
      return false;
    } catch (_) {
      Toast.show(S.current.customAssetInvalid);
      return false;
    }
  }

  Future<void> removeCustomAsset(WalletAsset asset) async {
    await _customAssetService.removeCustomAsset(asset);
    final keys = await _service.loadHiddenAssetKeys();
    keys.remove(_service.keyForAsset(asset));
    await _service.saveHiddenAssetKeys(keys);
    await loadVisibility();
  }
}

BoxDecoration _settingPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}
