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
import 'widgets/add_custom_asset_sheet.dart';
import 'widgets/chain_asset_visibility_card.dart';
import 'widgets/visibility_intro_card.dart';

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
          const VisibilityIntroCard(),
          SizedBox(height: 12.h),
          ...WalletChain.values.map(
            (chain) => ChainAssetVisibilityCard(
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
      builder: (sheetContext) => AddCustomAssetSheet(
        chain: chain,
        onFetchMetadata: controller.fetchEvmTokenMetadata,
        onSubmit: controller.addCustomAsset,
      ),
    );
  }
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
