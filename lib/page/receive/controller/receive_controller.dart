import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_asset.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_custom_asset_service.dart';

class ReceiveController extends BaseController {
  ReceiveController({WalletCustomAssetService? customAssetService})
    : _customAssetService = customAssetService ?? WalletCustomAssetService();

  final WalletCustomAssetService _customAssetService;

  WalletAccount? wallet;
  List<WalletAsset> customAssets = [];
  WalletChain selectedChain = WalletChain.bsc;
  WalletAsset? selectedAsset;
  bool isLoadingAssets = false;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is WalletAccount) {
      wallet = args;
    }
    _selectFirstAvailableAsset();
    loadAssets();
  }

  Future<void> loadAssets() async {
    isLoadingAssets = true;
    update();
    customAssets = await _customAssetService.loadCustomAssets();
    _selectFirstAvailableAsset();
    isLoadingAssets = false;
    update();
  }

  List<WalletAsset> assetsForSelectedChain() {
    return WalletAssetRegistry.mergeCustomAssets(selectedChain, customAssets);
  }

  void selectChain(WalletChain chain) {
    if (selectedChain == chain) return;
    selectedChain = chain;
    _selectFirstAvailableAsset();
    update();
  }

  void selectAsset(WalletAsset asset) {
    selectedAsset = asset;
    update();
  }

  String currentAddress() {
    final currentWallet = wallet;
    if (currentWallet == null) return '';
    switch (selectedChain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
        return currentWallet.bscAddress;
      case WalletChain.solana:
        return currentWallet.solanaAddress;
      case WalletChain.tron:
        return currentWallet.tronAddress;
    }
  }

  void _selectFirstAvailableAsset() {
    final assets = assetsForSelectedChain();
    if (assets.isEmpty) {
      selectedAsset = null;
      return;
    }
    final currentAsset = selectedAsset;
    if (currentAsset != null &&
        currentAsset.chain == selectedChain &&
        assets.any((asset) => asset.assetKey == currentAsset.assetKey)) {
      return;
    }
    selectedAsset = assets.first;
  }
}
