import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:dio/dio.dart';

import '../../utils/storage.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';
import 'wallet_transfer_service.dart';

class WalletCustomAssetService {
  WalletCustomAssetService({Storage? storage, Dio? dio})
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
  static const String _customAssetsKey = 'wallet_custom_assets';
  static const Duration _requestTimeout = Duration(seconds: 10);
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
  };

  Future<List<WalletAsset>> loadCustomAssets() async {
    try {
      final value = await _storage.getStorage(_customAssetsKey);
      if (value is List) {
        return value
            .whereType<Map>()
            .map(
              (item) => WalletAsset.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((asset) => asset.contractAddress?.trim().isNotEmpty ?? false)
            .toList(growable: false);
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  Future<void> saveCustomAssets(List<WalletAsset> assets) {
    return _storage.setStorage(
      _customAssetsKey,
      assets.map((asset) => asset.toJson()).toList(growable: false),
    );
  }

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

  Future<void> removeCustomAsset(WalletAsset asset) async {
    final normalizedAsset = _normalizeAsset(asset);
    final assets = [...await loadCustomAssets()]
      ..removeWhere((item) => _sameContractAsset(item, normalizedAsset));
    await saveCustomAssets(assets);
  }

  Future<WalletAsset> fetchEvmTokenMetadata({
    required WalletChain chain,
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
    return WalletAsset(
      chain: chain,
      symbol: symbol.toUpperCase(),
      name: name.isEmpty ? symbol.toUpperCase() : name,
      decimals: decimals,
      contractAddress: address,
      isCustom: true,
    );
  }

  WalletAsset buildManualAsset({
    required WalletChain chain,
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
    return WalletAsset(
      chain: chain,
      symbol: symbol.trim().toUpperCase(),
      name: name.trim(),
      decimals: decimals,
      contractAddress: normalizedAddress,
      isCustom: true,
    );
  }

  Future<String> _evmCall({
    required WalletChain chain,
    required String to,
    required String data,
  }) async {
    Object? lastError;
    for (final rpcUrl in _evmRpcFallbacks[chain] ?? [chain.rpcUrl]) {
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

  BigInt _decodeAbiUint(String value) {
    final clean = value.replaceFirst('0x', '');
    if (clean.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(clean, radix: 16);
  }

  WalletAsset _normalizeAsset(WalletAsset asset) {
    return WalletAsset(
      chain: asset.chain,
      symbol: asset.symbol.trim().toUpperCase(),
      name: asset.name.trim(),
      decimals: asset.decimals,
      contractAddress: _normalizeAddress(asset.chain, asset.contractAddress),
      isCustom: true,
    );
  }

  String _normalizeAddress(WalletChain chain, String? address) {
    final value = address?.trim() ?? '';
    if (value.isEmpty) {
      throw const CustomAssetInvalidInputException();
    }
    if (chain.isEvm) {
      return WalletTransferService.normalizeEvmAddress(value);
    }
    if (chain == WalletChain.tron) {
      WalletTransferService.tronAddressToHex(value);
      return value;
    }
    if (chain == WalletChain.solana) {
      WalletTransferService.normalizeSolanaAddress(value);
      return value;
    }
    return value;
  }

  bool _containsAsset(List<WalletAsset> assets, WalletAsset target) {
    return assets.any((asset) => _sameContractAsset(asset, target));
  }

  bool _sameContractAsset(WalletAsset asset, WalletAsset target) {
    return asset.chain == target.chain &&
        _contractKey(asset.chain, asset.contractAddress) ==
            _contractKey(target.chain, target.contractAddress);
  }

  String _contractKey(WalletChain chain, String? contractAddress) {
    final value = contractAddress?.trim() ?? '';
    if (value.isEmpty) {
      return 'native';
    }
    return chain.isEvm ? value.toLowerCase() : value;
  }
}

class CustomAssetException implements Exception {
  const CustomAssetException();
}

class CustomAssetDuplicateException extends CustomAssetException {
  const CustomAssetDuplicateException();
}

class CustomAssetInvalidInputException extends CustomAssetException {
  const CustomAssetInvalidInputException();
}

class CustomAssetInvalidMetadataException extends CustomAssetException {
  const CustomAssetInvalidMetadataException();
}

class CustomAssetUnsupportedChainException extends CustomAssetException {
  const CustomAssetUnsupportedChainException();
}
