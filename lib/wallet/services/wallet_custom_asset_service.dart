import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:dio/dio.dart';

import '../../utils/storage.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';
import 'wallet_chain_config_service.dart';
import 'wallet_transfer_service.dart';

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
  }) : _storage = storage ?? Storage(),
       _chainConfigService = chainConfigService ?? WalletChainConfigService(),
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

  /// 本地存储中保存自定义资产列表的字段名。
  static const String _customAssetsKey = 'wallet_custom_assets';

  /// 查询代币元数据时的请求超时时间。
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// EVM 链元数据查询备用 RPC 节点。
  ///
  /// 添加自定义 EVM 资产时需要调用合约的 symbol/name/decimals。公共节点不稳定时，
  /// 按顺序切换到备用节点，提高添加成功率。
  static const Map<WalletChain, List<String>> _evmRpcFallbacks = {
    WalletChain.bsc: [
      'https://bsc-dataseed.bnbchain.org',
      'https://bsc-rpc.publicnode.com',
    ],
    WalletChain.ethereum: [
      'https://ethereum-rpc.publicnode.com',
      'https://eth.llamarpc.com',
    ],
    WalletChain.xLayer: [
      'https://rpc.xlayer.tech',
      'https://xlayerrpc.okx.com',
    ],
    WalletChain.arbitrum: [
      'https://arb1.arbitrum.io/rpc',
      'https://arbitrum-one-rpc.publicnode.com',
    ],
  };

  /// 读取用户已添加的自定义资产。
  ///
  /// 存储异常或旧数据结构异常时返回空列表，避免设置页/首页因为脏数据崩溃。
  /// 只保留带合约地址的资产，原生币不允许作为自定义资产重复添加。
  Future<List<WalletAsset>> loadCustomAssets() async {
    try {
      final value = await _storage.getStorage(_customAssetsKey);
      if (value is List) {
        final assets = value
            .whereType<Map>()
            .map(
              (item) => WalletAsset.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((asset) => asset.contractAddress?.trim().isNotEmpty ?? false)
            .toList(growable: false);
        return _chainConfigService.bindAssetsToChains(assets);
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  /// 保存自定义资产列表。
  ///
  /// 资产会转换成 JSON 兼容结构写入本地存储。
  Future<void> saveCustomAssets(List<WalletAsset> assets) {
    return _storage.setStorage(
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
    if (!chain.isEvm) {
      throw const CustomAssetUnsupportedChainException();
    }
    final address = WalletTransferService.normalizeEvmAddress(contractAddress);
    final results = await Future.wait([
      _evmCall(chain: chain, to: address, data: '0x95d89b41'),
      _evmCall(chain: chain, to: address, data: '0x06fdde03'),
      _evmCall(chain: chain, to: address, data: '0x313ce567'),
    ]);
    final symbol = _decodeAbiString(results[0]).trim();
    final name = _decodeAbiString(results[1]).trim();
    final decimals = _decodeAbiUint(results[2]).toInt();
    if (symbol.isEmpty || decimals < 0 || decimals > 30) {
      throw const CustomAssetInvalidMetadataException();
    }
    return WalletAsset.config(
      chainConfig: chain,
      symbol: symbol.toUpperCase(),
      name: name.isEmpty ? symbol.toUpperCase() : name,
      decimals: decimals,
      contractAddress: address,
      isCustom: true,
    );
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
  }) {
    final normalizedAddress = _normalizeAddress(chain, contractAddress);
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
      isCustom: true,
    );
  }

  /// 执行一次 EVM `eth_call`。
  ///
  /// 添加代币时所有元数据读取都走该方法。它会遍历当前链的 RPC fallback 列表，
  /// 直到拿到字符串类型的 result。
  Future<String> _evmCall({
    required WalletChainRef chain,
    required String to,
    required String data,
  }) async {
    Object? lastError;
    for (final rpcUrl in _evmRpcUrls(chain)) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: {
            'jsonrpc': '2.0',
            'method': 'eth_call',
            'params': [
              {'to': to, 'data': data},
              'latest',
            ],
            'id': 1,
          },
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map && responseData['result'] is String) {
          return responseData['result'] as String;
        }
        throw StateError(responseData.toString());
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError(lastError?.toString() ?? 'EVM metadata lookup failed');
  }

  /// 解析 ABI string 返回值。
  ///
  /// 大多数 ERC20 合约返回动态 string，少数老合约返回 bytes32。这里兼容两种：
  /// - 动态 string：offset + length + utf8 bytes；
  /// - bytes32：固定 32 字节，去掉尾部 0 后按 UTF-8 解码。
  String _decodeAbiString(String value) {
    final clean = value.replaceFirst('0x', '');
    if (clean.isEmpty || clean == '0' || clean.length.isOdd) {
      return '';
    }
    if (clean.length >= 128) {
      final offset = BigInt.tryParse(
        clean.substring(0, 64),
        radix: 16,
      )?.toInt();
      final lengthWordStart = (offset ?? -1) * 2;
      if (offset != null &&
          offset >= 0 &&
          clean.length >= lengthWordStart + 64) {
        final length = BigInt.tryParse(
          clean.substring(lengthWordStart, lengthWordStart + 64),
          radix: 16,
        )?.toInt();
        if (length != null && length > 0) {
          final dataStart = lengthWordStart + 64;
          final dataEnd = dataStart + (length * 2);
          if (clean.length >= dataEnd) {
            return utf8.decode(
              hex.decode(clean.substring(dataStart, dataEnd)),
              allowMalformed: true,
            );
          }
        }
      }
    }

    if (clean.length == 64) {
      final bytes = hex.decode(clean);
      var end = bytes.length;
      while (end > 0 && bytes[end - 1] == 0) {
        end--;
      }
      final text = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
      if (text.trim().isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  /// 解析 ABI uint 返回值。
  ///
  /// decimals() 返回 uint8/uint256 时都可以按十六进制整数解析。
  BigInt _decodeAbiUint(String value) {
    final clean = value.replaceFirst('0x', '');
    if (clean.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(clean, radix: 16);
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
      contractAddress: _normalizeAddress(asset.chainRef, asset.contractAddress),
      isCustom: true,
    );
  }

  /// 按链类型校验和标准化合约地址。
  ///
  /// EVM 地址会被标准化为 checksum 地址；TRON/Solana 地址只做合法性校验并保留用户输入。
  String _normalizeAddress(WalletChainRef chain, String? address) {
    final value = address?.trim() ?? '';
    if (value.isEmpty) {
      throw const CustomAssetInvalidInputException();
    }
    if (chain.isEvm) {
      return WalletTransferService.normalizeEvmAddress(value);
    }
    if (_isTronChain(chain)) {
      WalletTransferService.tronAddressToHex(value);
      return value;
    }
    if (_isSolanaChain(chain)) {
      WalletTransferService.normalizeSolanaAddress(value);
      return value;
    }
    return value;
  }

  /// 判断资产列表中是否已存在目标资产。
  bool _containsAsset(List<WalletAsset> assets, WalletAsset target) {
    return assets.any((asset) => _sameContractAsset(asset, target));
  }

  /// 判断两个资产是否代表同一链上的同一合约。
  bool _sameContractAsset(WalletAsset asset, WalletAsset target) {
    return asset.chainId == target.chainId &&
        _contractKey(asset.chainRef, asset.contractAddress) ==
            _contractKey(target.chainRef, target.contractAddress);
  }

  /// 生成合约比较 key。
  ///
  /// EVM 合约地址大小写不敏感，比较时统一转小写；非 EVM 地址按原值比较。
  String _contractKey(WalletChainRef chain, String? contractAddress) {
    final value = contractAddress?.trim() ?? '';
    if (value.isEmpty) {
      return 'native';
    }
    return chain.isEvm ? value.toLowerCase() : value;
  }

  /// 判断当前链是否为 TRON。
  bool _isTronChain(WalletChainRef chain) {
    return chain.id == WalletChain.tron.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.tron);
  }

  /// 判断当前链是否为 Solana。
  bool _isSolanaChain(WalletChainRef chain) {
    return chain.id == WalletChain.solana.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.solana);
  }

  List<String> _evmRpcUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig && !chain.isBuiltin) {
      return chain.rpcUrls;
    }
    if (chain is WalletChain && _evmRpcFallbacks.containsKey(chain)) {
      return _evmRpcFallbacks[chain]!;
    }
    if (chain is WalletChainConfig && chain.builtinChain != null) {
      return _rpcUrlsWithFallbacks(
        chain.rpcUrls,
        _evmRpcFallbacks[chain.builtinChain] ?? const [],
      );
    }
    return [chain.rpcUrl];
  }

  /// 合并用户配置 RPC 和内置备用 RPC，按顺序去重。
  List<String> _rpcUrlsWithFallbacks(
    List<String> rpcUrls,
    List<String> fallbackRpcUrls,
  ) {
    final values = <String>{};
    for (final url in [...rpcUrls, ...fallbackRpcUrls]) {
      final normalized = url.trim();
      if (normalized.isNotEmpty) {
        values.add(normalized);
      }
    }
    return values.isEmpty ? const [] : values.toList(growable: false);
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

/// 当前链不支持自动读取资产元数据。
class CustomAssetUnsupportedChainException extends CustomAssetException {
  const CustomAssetUnsupportedChainException();
}
