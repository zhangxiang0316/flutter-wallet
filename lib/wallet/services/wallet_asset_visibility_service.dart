import '../../utils/storage.dart';
import '../models/chain_balance.dart';
import '../models/wallet_asset.dart';

class WalletAssetVisibilityService {
  WalletAssetVisibilityService({Storage? storage})
    : _storage = storage ?? Storage();

  final Storage _storage;
  static const String _hiddenAssetsKey = 'wallet_hidden_assets';

  Future<Set<String>> loadHiddenAssetKeys() async {
    final value = await _storage.getStorage(_hiddenAssetsKey);
    if (value is List) {
      return value.map((item) => item.toString()).toSet();
    }
    return {};
  }

  Future<void> saveHiddenAssetKeys(Set<String> keys) {
    return _storage.setStorage(_hiddenAssetsKey, keys.toList(growable: false));
  }

  Future<void> setAssetVisible({
    required WalletAsset asset,
    required bool visible,
  }) async {
    final keys = await loadHiddenAssetKeys();
    final key = keyForAsset(asset);
    if (visible) {
      keys.remove(key);
    } else {
      keys.add(key);
    }
    await saveHiddenAssetKeys(keys);
  }

  bool isBalanceVisible(ChainBalance balance, Set<String> hiddenKeys) {
    return !hiddenKeys.contains(keyForBalance(balance));
  }

  String keyForAsset(WalletAsset asset) {
    return [
      asset.chain.id,
      asset.contractAddress ?? 'native',
      asset.symbol,
    ].join(':');
  }

  String keyForBalance(ChainBalance balance) {
    return [
      balance.chain.id,
      balance.contractAddress ?? 'native',
      balance.symbol,
    ].join(':');
  }
}
