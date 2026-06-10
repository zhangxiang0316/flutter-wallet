import 'package:dio/dio.dart';

import '../../utils/storage.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';

/// 钱包网络配置服务。
///
/// 内置链由代码提供，用户自定义链保存在本地。第一版动态网络只支持 EVM，
/// 因为它们可以复用同一个地址、余额查询和转账签名逻辑。
class WalletChainConfigService {
  WalletChainConfigService({Storage? storage, Dio? dio})
    : _storage = storage ?? Storage(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          );

  final Storage _storage;
  final Dio _dio;

  static const String _customChainsKey = 'wallet_custom_evm_chains';
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// 内置链列表。
  ///
  /// 保持 enum 顺序，避免首页、收款、转账下拉顺序突然变化。
  List<WalletChainConfig> builtinChains() {
    return WalletChain.values
        .map((chain) => chain.config)
        .toList(growable: false);
  }

  /// 读取所有启用链，包括内置链和用户添加的 EVM 链。
  Future<List<WalletChainConfig>> loadEnabledChains() async {
    final chains = [...builtinChains(), ...await loadCustomChains()];
    return chains.where((chain) => chain.isEnabled).toList(growable: false);
  }

  /// 读取设置页需要展示的所有链。
  Future<List<WalletChainConfig>> loadAllChains() async {
    return [...builtinChains(), ...await loadCustomChains()];
  }

  /// 读取用户添加的 EVM 链。
  Future<List<WalletChainConfig>> loadCustomChains() async {
    final value = await _storage.getStorage(_customChainsKey);
    if (value is! List) {
      return [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => WalletChainConfig.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((chain) => _isValidCustomEvmChain(chain))
        .toList(growable: false);
  }

  /// 保存用户添加的 EVM 链列表。
  Future<void> saveCustomChains(List<WalletChainConfig> chains) {
    final values = chains
        .where(_isValidCustomEvmChain)
        .map((chain) => chain.toJson())
        .toList(growable: false);
    return _storage.setStorage(_customChainsKey, values);
  }

  /// 根据 ID 查找链配置。
  Future<WalletChainConfig?> findChain(String chainId) async {
    final chains = await loadAllChains();
    for (final chain in chains) {
      if (chain.id == chainId) {
        return chain;
      }
    }
    return null;
  }

  /// 把从本地读取的资产重新绑定到最新链配置。
  ///
  /// 动态 EVM 链资产持久化时只保存 chainId 和基础链信息，真正 RPC 列表以链配置为准。
  Future<List<WalletAsset>> bindAssetsToChains(List<WalletAsset> assets) async {
    final chains = {for (final chain in await loadAllChains()) chain.id: chain};
    return assets
        .map((asset) {
          final chain = chains[asset.chainId];
          if (chain == null) {
            return asset;
          }
          return WalletAsset.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            decimals: asset.decimals,
            contractAddress: asset.contractAddress,
            isCustom: asset.isCustom,
          );
        })
        .toList(growable: false);
  }

  /// 添加自定义 EVM 链。
  ///
  /// 会先校验 RPC 返回的 `eth_chainId`，确保用户填写的 chainId 和节点一致。
  Future<WalletChainConfig> addCustomEvmChain({
    required String name,
    required String symbol,
    required int evmChainId,
    required List<String> rpcUrls,
  }) async {
    final normalizedName = name.trim();
    final normalizedSymbol = symbol.trim().toUpperCase();
    final normalizedRpcUrls = _normalizeRpcUrls(rpcUrls);
    if (normalizedName.isEmpty ||
        normalizedSymbol.isEmpty ||
        evmChainId <= 0 ||
        normalizedRpcUrls.isEmpty) {
      throw const WalletChainConfigInvalidException();
    }

    final workingRpcUrls = await _validateEvmRpcUrls(
      rpcUrls: normalizedRpcUrls,
      evmChainId: evmChainId,
    );

    final nextChain = WalletChainConfig.customEvm(
      id: _customEvmChainId(evmChainId),
      name: normalizedName,
      symbol: normalizedSymbol,
      rpcUrls: workingRpcUrls,
      evmChainId: evmChainId,
      colorValue: _colorForChainId(evmChainId),
    );
    final customChains = [...await loadCustomChains()];
    final allChainIds = builtinChains().map((chain) => chain.id).toSet();
    final allEvmChainIds = builtinChains()
        .map((chain) => chain.evmChainId)
        .whereType<int>()
        .toSet();
    if (allChainIds.contains(nextChain.id) ||
        allEvmChainIds.contains(evmChainId) ||
        customChains.any(
          (chain) => chain.id == nextChain.id || chain.evmChainId == evmChainId,
        )) {
      throw const WalletChainConfigDuplicateException();
    }
    customChains.add(nextChain);
    await saveCustomChains(customChains);
    return nextChain;
  }

  /// 校验用户输入的多条 EVM RPC。
  ///
  /// 公共 RPC 经常下线、限流或需要 API Key。这里逐条请求 `eth_chainId`，只要有一条
  /// 可用且链 ID 匹配，就允许添加网络，并把可用节点排到第一位作为后续查询入口。
  Future<List<String>> _validateEvmRpcUrls({
    required List<String> rpcUrls,
    required int evmChainId,
  }) async {
    var sawMismatchedRpc = false;
    for (final rpcUrl in rpcUrls) {
      try {
        final rpcChainId = await fetchEvmChainId(rpcUrl);
        if (rpcChainId == evmChainId) {
          return [rpcUrl, ...rpcUrls.where((url) => url != rpcUrl)];
        }
        sawMismatchedRpc = true;
      } on WalletChainConfigRpcUnavailableException {
        continue;
      }
    }
    if (sawMismatchedRpc) {
      throw const WalletChainConfigRpcMismatchException();
    }
    throw const WalletChainConfigRpcUnavailableException();
  }

  /// 删除用户添加的链；内置链不能删除。
  Future<void> removeCustomChain(String chainId) async {
    final chains = [...await loadCustomChains()]
      ..removeWhere((chain) => chain.id == chainId);
    await saveCustomChains(chains);
  }

  /// 更新用户添加链的启用状态。
  Future<void> setCustomChainEnabled({
    required String chainId,
    required bool enabled,
  }) async {
    final chains = [
      for (final chain in await loadCustomChains())
        if (chain.id == chainId) chain.copyWith(isEnabled: enabled) else chain,
    ];
    await saveCustomChains(chains);
  }

  /// 通过 EVM RPC 查询链 ID。
  Future<int> fetchEvmChainId(String rpcUrl) async {
    try {
      final response = await _dio.post(
        rpcUrl.trim(),
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_chainId',
          'params': const [],
          'id': 1,
        },
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      final result = data is Map ? data['result'] : null;
      if (result is String && result.startsWith('0x')) {
        return int.parse(result.substring(2), radix: 16);
      }
    } catch (_) {
      throw const WalletChainConfigRpcUnavailableException();
    }
    throw const WalletChainConfigRpcUnavailableException();
  }

  List<String> _normalizeRpcUrls(List<String> rpcUrls) {
    return rpcUrls
        .map((url) => url.trim())
        .where((url) => url.startsWith('http://') || url.startsWith('https://'))
        .toSet()
        .toList(growable: false);
  }

  bool _isValidCustomEvmChain(WalletChainConfig chain) {
    return !chain.isBuiltin &&
        chain.type == WalletChainType.evm &&
        chain.id.trim().isNotEmpty &&
        chain.name.trim().isNotEmpty &&
        chain.symbol.trim().isNotEmpty &&
        chain.evmChainId != null &&
        chain.rpcUrls.isNotEmpty;
  }

  String _customEvmChainId(int chainId) => 'evm-$chainId';

  int _colorForChainId(int chainId) {
    const colors = [
      0xFF2563EB,
      0xFF059669,
      0xFF7C3AED,
      0xFFDC2626,
      0xFF0891B2,
      0xFF9333EA,
      0xFFEA580C,
    ];
    return colors[chainId.abs() % colors.length];
  }
}

class WalletChainConfigException implements Exception {
  const WalletChainConfigException();
}

class WalletChainConfigInvalidException extends WalletChainConfigException {
  const WalletChainConfigInvalidException();
}

class WalletChainConfigDuplicateException extends WalletChainConfigException {
  const WalletChainConfigDuplicateException();
}

class WalletChainConfigRpcMismatchException extends WalletChainConfigException {
  const WalletChainConfigRpcMismatchException();
}

class WalletChainConfigRpcUnavailableException
    extends WalletChainConfigException {
  const WalletChainConfigRpcUnavailableException();
}
