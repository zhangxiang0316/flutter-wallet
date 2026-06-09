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
/// 资产显示设置页面。
///
/// 用户可以按链控制默认币种和自定义币种是否在首页资产列表展示，
/// 也可以从当前页面为指定链添加自定义资产。
// ignore: use_key_in_widget_constructors, must_be_immutable
class AssetVisibilityPage extends BaseScaffoldPage<AssetVisibilityController> {
  /// 创建资产显示控制器，负责读取隐藏资产和自定义资产配置。
  @override
  AssetVisibilityController generateController() {
    return AssetVisibilityController();
  }

  /// 设置页顶部导航栏。
  @override
  PreferredSizeWidget? getAppBar() {
    // 当前主题色用于标题、返回按钮和底部分隔线。
    final colorScheme = Theme.of(context!).colorScheme;

    // AppBar 底部细分隔线，降低透明度以贴近 Vant 风格。
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

  /// 页面主体内容。
  ///
  /// 顶部展示说明卡片，下方按 [WalletChain.values] 渲染每条链的资产显示设置。
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

  /// 打开指定链的自定义资产添加弹窗。
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

/// 资产显示设置控制器。
///
/// 负责管理隐藏资产 key、自定义资产列表，并把页面操作同步到本地存储服务。
class AssetVisibilityController extends BaseController {
  AssetVisibilityController({
    WalletAssetVisibilityService? service,
    WalletCustomAssetService? customAssetService,
  }) : _service = service ?? WalletAssetVisibilityService(),
       _customAssetService = customAssetService ?? WalletCustomAssetService();

  /// 资产显示/隐藏配置服务。
  final WalletAssetVisibilityService _service;

  /// 用户自定义资产服务。
  final WalletCustomAssetService _customAssetService;

  /// 当前被隐藏的资产 key 集合。
  Set<String> hiddenAssetKeys = {};

  /// 用户手动添加的自定义资产列表。
  List<WalletAsset> customAssets = [];

  /// 初始化时加载本地资产显示配置。
  @override
  void onInit() {
    super.onInit();
    loadVisibility();
  }

  /// 重新读取隐藏资产和自定义资产配置，并刷新页面。
  Future<void> loadVisibility() async {
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    customAssets = await _customAssetService.loadCustomAssets();
    update();
  }

  /// 获取指定链下最终展示在设置页中的资产列表。
  ///
  /// 默认资产和用户自定义资产在这里合并，避免 UI 层关心资产来源。
  List<WalletAsset> assetsForChain(WalletChain chain) {
    return WalletAssetRegistry.mergeCustomAssets(chain, customAssets);
  }

  /// 判断某个资产当前是否允许在首页展示。
  bool isAssetVisible(WalletAsset asset) {
    return !hiddenAssetKeys.contains(_service.keyForAsset(asset));
  }

  /// 更新单个资产的显示/隐藏状态。
  Future<void> setAssetVisible(WalletAsset asset, bool visible) async {
    await _service.setAssetVisible(asset: asset, visible: visible);
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    update();
  }

  /// 从链上查询 EVM 合约资产元数据。
  ///
  /// 查询失败时返回 null，由弹窗展示“无法获取”的提示。
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

  /// 添加用户手动录入的自定义资产。
  ///
  /// 添加成功后会自动设置为可见，并重新加载页面数据。
  Future<bool> addCustomAsset({
    required WalletChain chain,
    required String contractAddress,
    required String symbol,
    required String name,
    required int decimals,
  }) async {
    try {
      // 将用户输入标准化成钱包资产模型。
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

  /// 移除用户自定义资产，并清理对应的隐藏配置。
  Future<void> removeCustomAsset(WalletAsset asset) async {
    await _customAssetService.removeCustomAsset(asset);

    // 自定义资产被删除后，它的隐藏 key 也不再需要保留。
    final keys = await _service.loadHiddenAssetKeys();
    keys.remove(_service.keyForAsset(asset));
    await _service.saveHiddenAssetKeys(keys);
    await loadVisibility();
  }
}
