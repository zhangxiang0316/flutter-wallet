import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_asset.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/config/wallet_asset_visibility_service.dart';
import '../../../wallet/services/config/wallet_chain_config_service.dart';
import '../../../wallet/services/config/wallet_custom_asset_service.dart';
import '../../home/controller/home_controller.dart';

/// 资产显示设置控制器。
///
/// 负责管理隐藏资产 key、自定义资产列表，并把页面操作同步到本地存储服务。
class AssetVisibilityController extends BaseController {
  AssetVisibilityController({
    WalletAssetVisibilityService? service,
    WalletCustomAssetService? customAssetService,
    WalletChainConfigService? chainConfigService,
  }) : _service = service ?? WalletAssetVisibilityService(),
       _customAssetService = customAssetService ?? WalletCustomAssetService(),
       _chainConfigService = chainConfigService ?? WalletChainConfigService();

  /// 资产显示/隐藏配置服务。
  final WalletAssetVisibilityService _service;

  /// 用户自定义资产服务。
  final WalletCustomAssetService _customAssetService;

  /// 动态链配置服务。
  final WalletChainConfigService _chainConfigService;

  /// 当前被隐藏的资产 key 集合。
  Set<String> hiddenAssetKeys = {};

  /// 用户手动添加的自定义资产列表。
  List<WalletAsset> customAssets = [];

  /// 设置页当前展示的链列表。
  List<WalletChainConfig> chains = [];

  /// 初始化时加载本地资产显示配置。
  @override
  void onInit() {
    super.onInit();
    loadVisibility();
  }

  /// 重新读取隐藏资产和自定义资产配置，并刷新页面。
  Future<void> loadVisibility() async {
    hiddenAssetKeys = await _service.loadHiddenAssetKeys();
    chains = await _chainConfigService.loadAllChains();
    customAssets = await _customAssetService.loadCustomAssets();
    update();
  }

  /// 获取指定链下最终展示在设置页中的资产列表。
  List<WalletAsset> assetsForChain(WalletChainConfig chain) {
    return WalletAssetRegistry.mergeCustomAssetsForChainConfig(
      chain,
      customAssets,
    );
  }

  /// 获取指定链的热门资产列表（排除已添加的）。
  List<WalletAsset> popularAssetsForChain(WalletChainConfig chain) {
    final existingContracts = assetsForChain(chain)
        .where((asset) => !asset.isNative)
        .map((asset) => _contractKey(asset))
        .toSet();
    return WalletCustomAssetService.popularAssetsForChain(chain)
        .where((asset) => existingContracts.add(_contractKey(asset)))
        .toList(growable: false);
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
  Future<WalletAsset?> fetchEvmTokenMetadata({
    required WalletChainConfig chain,
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
  Future<bool> addCustomAsset({
    required WalletChainConfig chain,
    required String contractAddress,
    required String symbol,
    required String name,
    required int decimals,
    bool metadataVerified = false,
    String? logoUrl,
    String? canonicalTokenId,
  }) async {
    try {
      final asset = _customAssetService.buildManualAsset(
        chain: chain,
        contractAddress: contractAddress,
        symbol: symbol,
        name: name,
        decimals: decimals,
        metadataVerified: metadataVerified,
        logoUrl: logoUrl,
        canonicalTokenId: canonicalTokenId,
      );
      await _customAssetService.addCustomAsset(asset);
      await _service.setAssetVisible(asset: asset, visible: true);
      await loadVisibility();
      _refreshHomeBalances();
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
    final keys = await _service.loadHiddenAssetKeys();
    keys.remove(_service.keyForAsset(asset));
    await _service.saveHiddenAssetKeys(keys);
    await loadVisibility();
    _refreshHomeBalances();
  }

  void _refreshHomeBalances() {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().refreshBalances();
    }
  }

  String _contractKey(WalletAsset asset) {
    final contractAddress = asset.contractAddress?.trim() ?? '';
    if (contractAddress.isEmpty) return 'native';
    return asset.chainRef.isEvm
        ? contractAddress.toLowerCase()
        : contractAddress;
  }
}
