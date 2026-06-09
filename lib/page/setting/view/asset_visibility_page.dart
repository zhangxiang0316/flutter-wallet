import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../wallet/models/wallet_asset.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_asset_visibility_service.dart';

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
              assets: WalletAssetRegistry.assetsForChain(chain),
              isVisible: controller.isAssetVisible,
              onChanged: controller.setAssetVisible,
            ).marginOnly(bottom: 12.h),
          ),
        ],
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
  });

  final WalletChain chain;
  final List<WalletAsset> assets;
  final bool Function(WalletAsset asset) isVisible;
  final Future<void> Function(WalletAsset asset, bool visible) onChanged;

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
            ],
          ).marginOnly(bottom: 8.h),
          ...assets.map(
            (asset) => _AssetVisibilityTile(
              asset: asset,
              visible: isVisible(asset),
              onChanged: (visible) => onChanged(asset, visible),
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
  });

  final WalletAsset asset;
  final bool visible;
  final ValueChanged<bool> onChanged;

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
              asset.symbol.characters.first,
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
          Switch.adaptive(value: visible, onChanged: onChanged),
        ],
      ),
    );
  }
}

class AssetVisibilityController extends BaseController {
  AssetVisibilityController({WalletAssetVisibilityService? service})
    : _service = service ?? WalletAssetVisibilityService();

  final WalletAssetVisibilityService _service;
  Set<String> hiddenAssetKeys = {};

  @override
  void onInit() {
    super.onInit();
    loadVisibility();
  }

  Future<void> loadVisibility() async {
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    update();
  }

  bool isAssetVisible(WalletAsset asset) {
    return !hiddenAssetKeys.contains(_service.keyForAsset(asset));
  }

  Future<void> setAssetVisible(WalletAsset asset, bool visible) async {
    await _service.setAssetVisible(asset: asset, visible: visible);
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    update();
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
