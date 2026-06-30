import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../controller/asset_visibility_controller.dart';
import 'widgets/add_custom_asset_sheet.dart';
import 'widgets/chain_asset_visibility_card.dart';
import 'widgets/visibility_intro_card.dart';

@GetXRoutePage('/assetVisibility')
/// 资产显示设置页面。
///
/// 用户可以按链控制默认币种和自定义币种是否在首页资产列表展示，
/// 也可以从当前页面为指定链添加自定义资产。
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
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
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
          ...controller.chains.map(
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

  void _showAddAssetSheet(WalletChainConfig chain) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddCustomAssetSheet(
        chain: chain,
        popularAssets: controller.popularAssetsForChain(chain),
        onFetchMetadata: controller.fetchEvmTokenMetadata,
        onSubmit: controller.addCustomAsset,
      ),
    );
  }
}
