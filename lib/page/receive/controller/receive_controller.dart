import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_asset.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/config/wallet_chain_config_service.dart';
import '../../../wallet/services/config/wallet_custom_asset_service.dart';

/// 收款页面控制器。
///
/// 页面只展示地址和二维码，不需要读取私钥。控制器负责读取路由传入的钱包、
/// 加载用户自定义资产，并维护当前选择的链和币种。
class ReceiveController extends BaseController {
  ReceiveController({
    WalletCustomAssetService? customAssetService,
    WalletChainConfigService? chainConfigService,
  }) : _customAssetService = customAssetService ?? WalletCustomAssetService(),
       _chainConfigService = chainConfigService ?? WalletChainConfigService();

  final WalletCustomAssetService _customAssetService;
  final WalletChainConfigService _chainConfigService;

  /// 首页传入的当前钱包，包含 EVM、Solana 和 TRON 地址。
  WalletAccount? wallet;

  /// 用户手动添加的自定义资产，用于补充默认资产列表。
  List<WalletAsset> customAssets = [];

  /// 当前启用的收款链配置。
  List<WalletChainConfig> chains = [];

  /// 当前二维码和地址使用的链。
  WalletChainConfig selectedChain = WalletChain.bsc.config;

  /// 当前选择的收款币种。
  WalletAsset? selectedAsset;

  /// 是否正在读取自定义资产配置。
  bool isLoadingAssets = false;

  /// 可选收款金额输入。
  final TextEditingController amountController = TextEditingController();

  /// 可选收款备注输入。
  final TextEditingController memoController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    amountController.addListener(update);
    memoController.addListener(update);
    final args = Get.arguments;
    if (args is WalletAccount) {
      wallet = args;
    }
    _selectFirstAvailableAsset();
    loadAssets();
  }

  @override
  void onClose() {
    amountController.dispose();
    memoController.dispose();
    super.onClose();
  }

  /// 读取用户自定义资产，并在加载完成后刷新当前链的币种选择。
  Future<void> loadAssets() async {
    isLoadingAssets = true;
    update();
    chains = await _chainConfigService.loadEnabledChains();
    if (!chains.any((chain) => chain.id == selectedChain.id)) {
      selectedChain = chains.isEmpty ? WalletChain.bsc.config : chains.first;
    }
    customAssets = await _customAssetService.loadCustomAssets();
    _selectFirstAvailableAsset();
    isLoadingAssets = false;
    update();
  }

  /// 获取当前链下所有可选收款资产。
  ///
  /// 默认资产和用户自定义资产在这里合并，页面只关心最终可选列表。
  List<WalletAsset> assetsForSelectedChain() {
    return WalletAssetRegistry.mergeCustomAssetsForChainConfig(
      selectedChain,
      customAssets,
    );
  }

  /// 切换收款链，并自动选择该链第一个可用币种。
  void selectChain(WalletChainConfig chain) {
    if (selectedChain.id == chain.id) return;
    selectedChain = chain;
    _selectFirstAvailableAsset();
    update();
  }

  /// 切换收款币种。
  void selectAsset(WalletAsset asset) {
    selectedAsset = asset;
    update();
  }

  /// 返回当前链对应的钱包地址。
  ///
  /// EVM 兼容链共用 EVM 地址；Bitcoin、Solana 和 TRON 使用各自地址。
  String currentAddress() {
    final currentWallet = wallet;
    if (currentWallet == null) return '';
    if (selectedChain.isEvm) {
      return currentWallet.bscAddress;
    }
    switch (selectedChain.builtinChain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
      case WalletChain.arbitrum:
      case WalletChain.base:
      case WalletChain.polygon:
        return currentWallet.bscAddress;
      case WalletChain.bitcoin:
        return currentWallet.bitcoinAddress;
      case WalletChain.solana:
        return currentWallet.solanaAddress;
      case WalletChain.sui:
        return currentWallet.suiAddress;
      case WalletChain.aptos:
        return currentWallet.aptosAddress;
      case WalletChain.tron:
        return currentWallet.tronAddress;
      case null:
        return currentWallet.bscAddress;
    }
  }

  /// 当前二维码内容。
  ///
  /// 未填写金额和备注时保持为纯地址，方便通用钱包直接识别；填写任一字段后使用
  /// 应用内收款 URI，携带链、资产、金额和备注。
  String currentQrPayload() {
    final address = currentAddress();
    if (address.trim().isEmpty) return '';
    final amount = amountController.text.trim();
    final memo = memoController.text.trim();
    final asset = selectedAsset;
    final contractAddress = asset?.contractAddress?.trim() ?? '';
    if (amount.isEmpty && memo.isEmpty) return address;
    return Uri(
      scheme: 'omnicast',
      host: 'receive',
      queryParameters: {
        'address': address,
        'chain': selectedChain.id,
        if (asset != null) 'symbol': asset.symbol,
        if (contractAddress.isNotEmpty) 'contract': contractAddress,
        if (amount.isNotEmpty) 'amount': amount,
        if (memo.isNotEmpty) 'memo': memo,
      },
    ).toString();
  }

  /// 保证 [selectedAsset] 始终指向当前链中存在的资产。
  void _selectFirstAvailableAsset() {
    final assets = assetsForSelectedChain();
    if (assets.isEmpty) {
      selectedAsset = null;
      return;
    }
    final currentAsset = selectedAsset;
    if (currentAsset != null &&
        currentAsset.chainId == selectedChain.id &&
        assets.any((asset) => asset.assetKey == currentAsset.assetKey)) {
      return;
    }
    selectedAsset = assets.first;
  }
}
