import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/digests/keccak.dart';

import '../../../utils/storage.dart';
import '../../adapters/chain_adapter.dart';
import '../../adapters/chain_adapter_registry.dart';
import '../../adapters/default_chain_adapter_registry.dart';
import '../../models/wallet_asset.dart';
import '../../models/wallet_asset_identity_policy.dart';
import '../../models/wallet_asset_registry.dart';
import '../../models/wallet_chain.dart';
import '../../utils/rpc_retry_helper.dart';
import 'wallet_chain_config_service.dart';
import '../wallet_transfer_service.dart';

part 'wallet_custom_asset_popular_assets.dart';
part 'wallet_custom_asset_utils.dart';
part 'wallet_custom_asset_evm_metadata.dart';

/// 用户自定义资产服务。
///
/// 设置页“添加显示币种”依赖该服务。它负责：
/// - 读取和保存用户手动添加的代币列表；
/// - 防止重复添加默认资产或已添加资产；
/// - 对 EVM 合约自动读取 symbol/name/decimals；
/// - 对 EVM/TRON/Solana 合约地址做基础格式校验。
///
/// 该服务只维护资产配置，不查询余额。余额查询由 [ChainBalanceService] 根据
/// 默认资产和这里保存的自定义资产合并后执行。
class WalletCustomAssetService {
  /// 创建自定义资产服务。
  ///
  /// 测试时可以注入 [Storage] 和 [Dio]，业务代码默认使用项目本地存储和独立 Dio。
  WalletCustomAssetService({
    Storage? storage,
    Dio? dio,
    WalletChainConfigService? chainConfigService,
    ChainAdapterRegistry? adapterRegistry,
  }) : _storage = storage ?? Storage(),
       _chainConfigService = chainConfigService ?? WalletChainConfigService(),
       _adapterRegistry =
           adapterRegistry ?? createDefaultChainAdapterRegistry(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: _requestTimeout,
               receiveTimeout: _requestTimeout,
               sendTimeout: _requestTimeout,
             ),
           );

  /// 自定义资产持久化存储。
  final Storage _storage;

  /// EVM 合约元数据查询使用的 HTTP/RPC 客户端。
  final Dio _dio;

  /// 动态链配置服务，用于把本地自定义资产重新绑定到最新链 RPC 配置。
  final WalletChainConfigService _chainConfigService;
  final ChainAdapterRegistry _adapterRegistry;

  /// 本地存储中保存自定义资产列表的字段名。
  static const String _customAssetsKey = 'wallet_custom_assets';

  /// 查询代币元数据时的请求超时时间。
  static const Duration _requestTimeout = Duration(seconds: 10);

  static List<WalletAsset> popularAssetsForChain(WalletChainConfig chain) {
    return _popularAssetsForChain(chain);
  }

  /// 读取用户已添加的自定义资产。
  ///
  /// 存储异常或旧数据结构异常时返回空列表，避免设置页/首页因为脏数据崩溃。
  /// 只保留带合约地址的资产，原生币不允许作为自定义资产重复添加。
  Future<List<WalletAsset>> loadCustomAssets() async {
    try {
      final customAssetsJson = await _storage.getJsonList(_customAssetsKey);
      if (customAssetsJson != null) {
        final assets = customAssetsJson
            .whereType<Map>()
            .map(
              (item) => WalletAsset.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((asset) => asset.contractAddress?.trim().isNotEmpty ?? false)
            .toList(growable: false);
        final boundAssets = await _chainConfigService.bindAssetsToChains(
          assets,
        );
        final needsChainMigration = List.generate(
          assets.length,
          (index) => assets[index].chainId != boundAssets[index].chainId,
        ).any((changed) => changed);
        final needsCanonicalMigration = customAssetsJson.whereType<Map>().any((
          item,
        ) {
          final storedId = WalletCanonicalToken.normalizeId(
            item['canonicalTokenId']?.toString(),
          );
          final migratedId = WalletAsset.fromJson(
            Map<String, dynamic>.from(item),
          ).canonicalTokenId;
          return migratedId != null && migratedId != storedId;
        });
        if (needsChainMigration || needsCanonicalMigration) {
          await saveCustomAssets(boundAssets);
        }
        return boundAssets;
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  /// 保存自定义资产列表。
  ///
  /// 同一条链上的同一合约一旦保存，decimals 视为不可变元数据。这样网络配置
  /// 更新、资产迁移或其他调用方即使重新写入列表，也不能悄悄改变余额和转账的数量级。
  Future<void> saveCustomAssets(List<WalletAsset> assets) async {
    final stored = await _storage.getJsonList(_customAssetsKey);
    final storedAssets = stored == null
        ? const <WalletAsset>[]
        : stored
              .whereType<Map>()
              .map(
                (item) => WalletAsset.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false);
    for (final asset in assets) {
      final previous = storedAssets.cast<WalletAsset?>().firstWhere(
        (item) => item != null && _sameContractAsset(item, asset),
        orElse: () => null,
      );
      if (previous != null && previous.decimals != asset.decimals) {
        throw const CustomAssetDecimalsImmutableException();
      }
      if (asset.decimals < 0 || asset.decimals > 30) {
        throw const CustomAssetInvalidInputException();
      }
    }
    return _storage.setJsonList(
      _customAssetsKey,
      assets.map((asset) => asset.toJson()).toList(growable: false),
    );
  }

  /// 添加一个自定义资产。
  ///
  /// 添加前会先标准化资产信息，再检查是否和默认资产或已有自定义资产重复。
  /// 重复判断以“链 + 合约地址”为准，而不是 symbol/name。
  Future<WalletAsset> addCustomAsset(WalletAsset asset) async {
    final normalizedAsset = _normalizeAsset(asset);
    final assets = [...await loadCustomAssets()];
    if (_containsAsset(WalletAssetRegistry.all, normalizedAsset) ||
        _containsAsset(assets, normalizedAsset)) {
      throw const CustomAssetDuplicateException();
    }

    assets.add(normalizedAsset);
    await saveCustomAssets(assets);
    return normalizedAsset;
  }

  /// 移除一个自定义资产。
  ///
  /// 同样使用标准化后的“链 + 合约地址”匹配，避免大小写差异导致 EVM 资产删不掉。
  Future<void> removeCustomAsset(WalletAsset asset) async {
    final normalizedAsset = _normalizeAsset(asset);
    final assets = [...await loadCustomAssets()]
      ..removeWhere((item) => _sameContractAsset(item, normalizedAsset));
    await saveCustomAssets(assets);
  }

  /// 从 EVM 合约自动读取代币元数据。
  ///
  /// 仅支持 EVM 链。方法选择器：
  /// - `0x95d89b41`: symbol()
  /// - `0x06fdde03`: name()
  /// - `0x313ce567`: decimals()
  ///
  /// symbol 为空或 decimals 不在合理范围内时，认为合约元数据无效。
  Future<WalletAsset> fetchEvmTokenMetadata({
    required WalletChainConfig chain,
    required String contractAddress,
  }) async {
    return _fetchEvmTokenMetadata(
      dio: _dio,
      chain: chain,
      contractAddress: contractAddress,
    );
  }

  /// 在签名前重新读取 EVM decimals，防止本地配置或缓存被篡改后按错误精度转账。
  Future<bool> verifyEvmTokenDecimals({
    required WalletChainConfig chain,
    required String contractAddress,
    required int expectedDecimals,
  }) async {
    try {
      final metadata = await fetchEvmTokenMetadata(
        chain: chain,
        contractAddress: contractAddress,
      );
      return metadata.decimals == expectedDecimals;
    } catch (_) {
      return false;
    }
  }

  /// 根据用户手动输入构造自定义资产。
  ///
  /// 用于非 EVM 链，或者 EVM 自动读取失败后用户手动填写 symbol/name/decimals 的场景。
  /// 这里会统一校验地址、非空文案和 decimals 范围。
  WalletAsset buildManualAsset({
    required WalletChainConfig chain,
    required String contractAddress,
    required String symbol,
    required String name,
    required int decimals,
    bool metadataVerified = false,
    String? logoUrl,
    String? canonicalTokenId,
  }) {
    final normalizedAddress = _normalizeAddress(
      chain,
      contractAddress,
      _adapterRegistry,
    );
    if (chain.isEvm && !metadataVerified) {
      throw const CustomAssetUnverifiedMetadataException();
    }
    if (symbol.trim().isEmpty || name.trim().isEmpty) {
      throw const CustomAssetInvalidInputException();
    }
    if (decimals < 0 || decimals > 30) {
      throw const CustomAssetInvalidInputException();
    }
    return WalletAsset.config(
      chainConfig: chain,
      symbol: symbol.trim().toUpperCase(),
      name: name.trim(),
      decimals: decimals,
      contractAddress: normalizedAddress,
      logoUrl:
          _normalizeLogoUrl(logoUrl) ??
          _defaultLogoUrl(chain, normalizedAddress),
      canonicalTokenId: WalletCanonicalToken.normalizeId(canonicalTokenId),
      isCustom: true,
    );
  }

  /// 标准化自定义资产对象。
  ///
  /// symbol 统一大写，name 去掉首尾空白，合约地址按链类型标准化，并强制标记为自定义资产。
  WalletAsset _normalizeAsset(WalletAsset asset) {
    return WalletAsset.config(
      chainConfig: asset.chainConfig ?? asset.chain!.config,
      symbol: asset.symbol.trim().toUpperCase(),
      name: asset.name.trim(),
      decimals: asset.decimals,
      contractAddress: _normalizeAddress(
        asset.chainRef,
        asset.contractAddress,
        _adapterRegistry,
      ),
      logoUrl: _normalizeLogoUrl(asset.logoUrl),
      canonicalTokenId: WalletCanonicalToken.normalizeId(
        asset.canonicalTokenId,
      ),
      isCustom: true,
    );
  }
}

/// 自定义资产相关异常基类。
class CustomAssetException implements Exception {
  const CustomAssetException();
}

/// 添加的资产已存在。
class CustomAssetDuplicateException extends CustomAssetException {
  const CustomAssetDuplicateException();
}

/// 用户输入的合约、符号、名称或精度不合法。
class CustomAssetInvalidInputException extends CustomAssetException {
  const CustomAssetInvalidInputException();
}

/// 自动读取到的链上合约元数据不完整或不可信。
class CustomAssetInvalidMetadataException extends CustomAssetException {
  const CustomAssetInvalidMetadataException();
}

/// 自定义 EVM 资产未经过链上 metadata 校验。
class CustomAssetUnverifiedMetadataException extends CustomAssetException {
  const CustomAssetUnverifiedMetadataException();
}

/// 已保存资产的 decimals 不允许被覆盖。
class CustomAssetDecimalsImmutableException extends CustomAssetException {
  const CustomAssetDecimalsImmutableException();
}

/// 当前链不支持自动读取资产元数据。
class CustomAssetUnsupportedChainException extends CustomAssetException {
  const CustomAssetUnsupportedChainException();
}
