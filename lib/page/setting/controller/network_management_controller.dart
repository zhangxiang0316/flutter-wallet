import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_chain_config_service.dart';
import '../../../wallet/services/wallet_custom_asset_service.dart';
import '../../../wallet/services/wallet_rpc_health_service.dart';

/// 网络管理页面控制器。
///
/// 负责链配置的增删改查、RPC 健康检测、节点切换和自定义链启用/禁用。
/// 页面 Widget 只消费这里整理好的状态，不直接访问链配置服务。
class NetworkManagementController extends BaseController {
  NetworkManagementController({
    WalletChainConfigService? service,
    WalletCustomAssetService? customAssetService,
    WalletRpcHealthService? rpcHealthService,
  }) : _service = service ?? WalletChainConfigService(),
       _customAssetService = customAssetService ?? WalletCustomAssetService(),
       _rpcHealthService = rpcHealthService ?? WalletRpcHealthService();

  final WalletChainConfigService _service;
  final WalletCustomAssetService _customAssetService;
  final WalletRpcHealthService _rpcHealthService;

  /// 当前所有链配置列表。
  List<WalletChainConfig> chains = [];

  /// 是否正在提交表单（防止重复提交）。
  bool isSubmitting = false;

  /// 各链的 RPC 健康检测报告，key 为链 ID。
  Map<String, WalletChainRpcHealthReport> healthReports = {};

  /// 正在检测中的链 ID 集合。
  Set<String> testingChainIds = {};

  @override
  void onInit() {
    super.onInit();
    loadChains();
  }

  /// 加载所有链配置。
  Future<void> loadChains() async {
    chains = await _service.loadAllChains();
    update();
  }

  /// 对指定链执行 RPC 健康检测。
  Future<void> testNetwork(WalletChainConfig chain) async {
    if (testingChainIds.contains(chain.id)) return;
    testingChainIds = {...testingChainIds, chain.id};
    update();
    try {
      final report = await _rpcHealthService.checkChain(chain);
      healthReports = {...healthReports, chain.id: report};
      final primary = report.primaryResult;
      final best = report.bestAvailableResult;
      if (primary?.isAvailable == true) {
        Toast.show(S.current.networkRpcTestAvailable);
      } else if (best != null) {
        Toast.show(S.current.networkRpcBackupAvailable);
      } else {
        Toast.show(S.current.networkRpcUnavailable);
      }
    } finally {
      testingChainIds = {...testingChainIds}..remove(chain.id);
      update();
    }
  }

  /// 切换链的主 RPC 节点，并自动重新检测。
  Future<void> switchPrimaryRpc(WalletChainConfig chain, String rpcUrl) async {
    try {
      await _service.setPrimaryRpcUrl(chain: chain, rpcUrl: rpcUrl);
      Toast.show(S.current.networkRpcSwitched);
      await loadChains();
      final updated = chains.firstWhereOrNull((item) => item.id == chain.id);
      if (updated != null) {
        await testNetwork(updated);
      }
    } catch (_) {
      Toast.show(S.current.networkInvalid);
    }
  }

  /// 新增 EVM 自定义链。
  Future<bool> addEvmChain({
    required String name,
    required String symbol,
    required int chainId,
    required List<String> rpcUrls,
    String? explorerApiUrl,
    String? explorerApiKey,
  }) async {
    if (isSubmitting) return false;
    try {
      isSubmitting = true;
      update();
      await _service.addCustomEvmChain(
        name: name,
        symbol: symbol,
        evmChainId: chainId,
        rpcUrls: rpcUrls,
        explorerApiUrl: explorerApiUrl,
        explorerApiKey: explorerApiKey,
      );
      Toast.show(S.current.networkAdded);
      await loadChains();
      return true;
    } on WalletChainConfigDuplicateException {
      Toast.show(S.current.networkDuplicate);
      return false;
    } on WalletChainConfigRpcMismatchException {
      Toast.show(S.current.networkRpcMismatch);
      return false;
    } on WalletChainConfigRpcUnavailableException {
      Toast.show(S.current.networkRpcUnavailable);
      return false;
    } catch (_) {
      Toast.show(S.current.networkInvalid);
      return false;
    } finally {
      isSubmitting = false;
      update();
    }
  }

  /// 切换自定义链的启用/禁用状态。
  Future<void> setEnabled(WalletChainConfig chain, bool enabled) async {
    await _service.setCustomChainEnabled(chainId: chain.id, enabled: enabled);
    await loadChains();
  }

  /// 更新链配置（内置链或自定义链均可）。
  Future<bool> updateNetwork({
    required WalletChainConfig chain,
    required String name,
    required String symbol,
    required List<String> rpcUrls,
    String? explorerApiUrl,
    String? explorerApiKey,
  }) async {
    if (isSubmitting) return false;
    try {
      isSubmitting = true;
      update();
      if (chain.isBuiltin) {
        await _service.updateBuiltinChain(
          chainId: chain.id,
          name: name,
          symbol: symbol,
          rpcUrls: rpcUrls,
          explorerApiUrl: explorerApiUrl,
          explorerApiKey: explorerApiKey,
        );
      } else {
        await _service.updateCustomEvmChain(
          chainId: chain.id,
          name: name,
          symbol: symbol,
          rpcUrls: rpcUrls,
          explorerApiUrl: explorerApiUrl,
          explorerApiKey: explorerApiKey,
        );
      }
      Toast.show(S.current.networkUpdated);
      await loadChains();
      return true;
    } on WalletChainConfigRpcMismatchException {
      Toast.show(S.current.networkRpcMismatch);
      return false;
    } on WalletChainConfigRpcUnavailableException {
      Toast.show(S.current.networkRpcUnavailable);
      return false;
    } catch (_) {
      Toast.show(S.current.networkInvalid);
      return false;
    } finally {
      isSubmitting = false;
      update();
    }
  }

  /// 删除自定义链及其关联的自定义资产。
  Future<void> removeChain(WalletChainConfig chain) async {
    final assets = await _customAssetService.loadCustomAssets();
    await _customAssetService.saveCustomAssets(
      assets
          .where((asset) => asset.chainId != chain.id)
          .toList(growable: false),
    );
    await _service.removeCustomChain(chain.id);
    Toast.show(S.current.networkRemoved);
    await loadChains();
  }
}
