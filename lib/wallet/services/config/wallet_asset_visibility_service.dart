import '../../../utils/storage.dart';
import '../../models/chain_balance.dart';
import '../../models/wallet_asset.dart';

/// 钱包资产显示/隐藏配置服务。
///
/// 该服务只负责保存“哪些资产被用户隐藏”，不负责查询余额或修改资产列表。
/// 首页刷新余额后，会把 [ChainBalance] 转成同样的 key，再用隐藏集合过滤展示。
class WalletAssetVisibilityService {
  /// 创建资产显示配置服务。
  ///
  /// 测试时可以注入自定义 [Storage]；业务场景默认使用项目统一的本地存储封装。
  WalletAssetVisibilityService({Storage? storage})
    : _storage = storage ?? Storage();

  /// 本地持久化存储。
  final Storage _storage;

  /// 本地存储中保存隐藏资产 key 列表的字段名。
  static const String _hiddenAssetsKey = 'wallet_hidden_assets';

  /// 读取用户已隐藏的资产 key 集合。
  ///
  /// 老数据或异常数据不是 List 时，返回空集合，表示所有资产默认展示。
  Future<Set<String>> loadHiddenAssetKeys() async {
    final hiddenAssetKeys = await _storage.getJsonList(_hiddenAssetsKey);
    if (hiddenAssetKeys != null) {
      final keys = hiddenAssetKeys.map((item) => item.toString()).toSet();
      final migratedKeys = keys.map(_migrateStoredKey).toSet();
      if (migratedKeys.length != keys.length ||
          !migratedKeys.containsAll(keys)) {
        await saveHiddenAssetKeys(migratedKeys);
      }
      return migratedKeys;
    }
    return {};
  }

  /// 保存隐藏资产 key 集合。
  ///
  /// Set 会转成 List 存储，因为底层 storage 通常只支持 JSON 兼容类型。
  Future<void> saveHiddenAssetKeys(Set<String> keys) {
    return _storage.setJsonList(_hiddenAssetsKey, keys.toList(growable: false));
  }

  /// 设置某个资产是否可见。
  ///
  /// [visible] 为 true 时从隐藏集合移除；为 false 时加入隐藏集合。
  /// 这里使用 [WalletAsset] 生成 key，适用于设置页中的默认资产和自定义资产。
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

  /// 判断某条余额记录是否应该展示。
  ///
  /// 首页拿到余额后使用 [ChainBalance] 生成 key。只要 key 不在隐藏集合中，就显示。
  bool isBalanceVisible(ChainBalance balance, Set<String> hiddenKeys) {
    return !hiddenKeys.contains(keyForBalance(balance));
  }

  /// 为资产配置生成稳定 key。
  ///
  /// key 由 `chainId:contractAddress/native:symbol` 组成。原生币没有合约地址，
  /// 统一使用 `native`，避免空字符串和 null 造成不同 key。
  String keyForAsset(WalletAsset asset) {
    return [
      asset.chainId,
      _normalizedContractKey(asset.contractAddress),
      asset.symbol,
    ].join(':');
  }

  /// 为余额记录生成稳定 key。
  ///
  /// 该方法必须和 [keyForAsset] 保持同一规则，否则设置页隐藏的资产无法正确过滤
  /// 首页余额列表。
  String keyForBalance(ChainBalance balance) {
    return [
      balance.chainId,
      _normalizedContractKey(balance.contractAddress),
      balance.symbol,
    ].join(':');
  }

  String _migrateStoredKey(String key) {
    var migratedKey = key;
    if (key.startsWith('evm-137:')) {
      final assetKey = key.substring('evm-137:'.length);
      migratedKey = assetKey == 'native:MATIC'
          ? 'polygon:native:POL'
          : 'polygon:$assetKey';
    } else if (key.startsWith('evm-43114:')) {
      migratedKey = 'avalanche:${key.substring('evm-43114:'.length)}';
    }

    final parts = migratedKey.split(':');
    if (parts.length < 3) return migratedKey;
    parts[1] = _normalizedContractKey(parts[1]);
    return parts.join(':');
  }

  String _normalizedContractKey(String? contractAddress) {
    final value = contractAddress?.trim() ?? '';
    if (value.isEmpty || value == 'native') return 'native';
    if (RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value)) {
      return value.toLowerCase();
    }
    return value;
  }
}
