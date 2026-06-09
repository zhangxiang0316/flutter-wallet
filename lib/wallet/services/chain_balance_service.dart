import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../models/chain_balance.dart';
import '../models/wallet_asset.dart';
import '../models/wallet_chain.dart';

class ChainBalanceService {
  ChainBalanceService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          );

  final Dio _dio;
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _solanaRequestTimeout = Duration(seconds: 3);
  static const Duration _solanaChainTimeout = Duration(seconds: 5);
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
  static const List<String> _tronRpcFallbacks = [
    'https://api.trongrid.io',
    'https://tron-rpc.publicnode.com',
  ];
  static const List<String> _solanaRpcFallbacks = [
    'https://api.mainnet-beta.solana.com',
    'https://solana-rpc.publicnode.com',
  ];

  Future<List<ChainBalance>> loadBalances({
    required String bscAddress,
    required String tronAddress,
    required String solanaAddress,
  }) async {
    final results = await Future.wait([
      _loadEvmBalances(
        chain: WalletChain.bsc,
        assets: WalletAssetRegistry.bscAssets,
        address: bscAddress,
      ),
      _loadEvmBalances(
        chain: WalletChain.ethereum,
        assets: WalletAssetRegistry.ethereumAssets,
        address: bscAddress,
      ),
      _loadEvmBalances(
        chain: WalletChain.xLayer,
        assets: WalletAssetRegistry.xLayerAssets,
        address: bscAddress,
      ),
      _loadSolanaBalances(solanaAddress).timeout(
        _solanaChainTimeout,
        onTimeout: () {
          developer.log(
            'Solana balance lookup timed out; using zero fallback balances',
            name: 'ChainBalanceService',
          );
          return _fallbackSolanaBalances(solanaAddress);
        },
      ),
      _loadTronBalances(tronAddress),
    ]);
    final balances = results.expand((items) => items).toList();
    _printLoadedBalances(results, balances);
    return balances;
  }

  Future<Map<dynamic, dynamic>> _postEvmRpc({
    required WalletChain chain,
    required Map<String, dynamic> data,
  }) async {
    Object? lastError;
    for (final rpcUrl in _evmRpcUrls(chain)) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: data,
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map && responseData['result'] is String) {
          return responseData;
        }
        if (responseData is Map && responseData['error'] != null) {
          throw StateError('${chain.name} RPC error: ${responseData['error']}');
        }
        throw StateError('Invalid ${chain.name} RPC response');
      } catch (error) {
        lastError = error;
        developer.log(
          '${chain.name} RPC request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      '${chain.name} RPC request failed: ${lastError ?? 'unknown error'}',
    );
  }

  List<String> _evmRpcUrls(WalletChain chain) {
    return _evmRpcFallbacks[chain] ?? [chain.rpcUrl];
  }

  Future<Map<dynamic, dynamic>> _postTronAccount(String address) async {
    Object? lastError;
    for (final rpcUrl in _tronRpcFallbacks) {
      try {
        final response = await _dio.post(
          '$rpcUrl/wallet/getaccount',
          data: {'address': address, 'visible': true},
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map) {
          if (responseData['Error'] != null || responseData['error'] != null) {
            throw StateError(
              'TRON RPC error: ${responseData['Error'] ?? responseData['error']}',
            );
          }
          return responseData;
        }
        throw StateError('Invalid TRON response');
      } catch (error) {
        lastError = error;
        developer.log(
          'TRON account request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      'TRON account request failed: ${lastError ?? 'unknown error'}',
    );
  }

  Future<Map<dynamic, dynamic>> _postSolanaRpc({
    required Map<String, dynamic> data,
  }) async {
    Object? lastError;
    for (final rpcUrl in _solanaRpcFallbacks) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: data,
          options: Options(
            headers: {'content-type': 'application/json'},
            sendTimeout: _solanaRequestTimeout,
            receiveTimeout: _solanaRequestTimeout,
          ),
        );
        final responseData = response.data;
        if (responseData is Map && responseData['result'] != null) {
          return responseData;
        }
        if (responseData is Map && responseData['error'] != null) {
          throw StateError('Solana RPC error: ${responseData['error']}');
        }
        throw StateError('Invalid Solana RPC response');
      } catch (error) {
        lastError = error;
        developer.log(
          'Solana RPC request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      'Solana RPC request failed: ${lastError ?? 'unknown error'}',
    );
  }

  void _printLoadedBalances(
    List<List<ChainBalance>> chainResults,
    List<ChainBalance> balances,
  ) {
    final buffer = StringBuffer()
      ..writeln('----- ChainBalanceService.loadBalances -----')
      ..writeln('total=${balances.length}');

    for (final chainBalances in chainResults) {
      final chainName = chainBalances.isEmpty
          ? 'empty'
          : chainBalances.first.chain.name;
      buffer.writeln('[$chainName] count=${chainBalances.length}');
      for (final balance in chainBalances) {
        buffer.writeln(
          '  ${balance.symbol} amount=${balance.amount} '
          'decimals=${balance.decimals} native=${balance.isNative} '
          'contract=${balance.contractAddress ?? '-'} '
          'error=${balance.error ?? '-'}',
        );
      }
    }

    developer.log(buffer.toString(), name: 'ChainBalanceService');
  }

  Future<List<ChainBalance>> _loadEvmBalances({
    required WalletChain chain,
    required List<WalletAsset> assets,
    required String address,
  }) async {
    return Future.wait(
      assets.map(
        (asset) => _loadEvmAsset(chain: chain, asset: asset, address: address),
      ),
    );
  }

  Future<ChainBalance> _loadEvmAsset({
    required WalletChain chain,
    required WalletAsset asset,
    required String address,
  }) async {
    if (asset.isNative) {
      return _loadEvmNativeBalance(
        chain: chain,
        asset: asset,
        address: address,
      );
    }
    return _loadEvmTokenBalance(chain: chain, asset: asset, address: address);
  }

  Future<ChainBalance> _loadEvmNativeBalance({
    required WalletChain chain,
    required WalletAsset asset,
    required String address,
  }) async {
    try {
      final data = await _postEvmRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
          'id': 1,
        },
      );
      final wei = _parseHexQuantity(data['result'] as String);
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(wei, asset.decimals),
        address: address,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  Future<ChainBalance> _loadEvmTokenBalance({
    required WalletChain chain,
    required WalletAsset asset,
    required String address,
  }) async {
    try {
      final data = await _postEvmRpc(
        chain: chain,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [
            {'to': asset.contractAddress, 'data': erc20BalanceOfData(address)},
            'latest',
          ],
          'id': 1,
        },
      );
      final value = _parseHexQuantity(data['result'] as String);
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(value, asset.decimals),
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  Future<List<ChainBalance>> _loadTronBalances(String address) async {
    final nativeBalance = await _loadTronNativeBalance(address);
    final tokenBalances = await _loadTronTokenBalances(address);
    final tokenMap = {
      for (final balance in tokenBalances)
        if (balance.contractAddress != null) balance.contractAddress!: balance,
    };
    final knownTokens = WalletAssetRegistry.tronAssets
        .where((asset) => !asset.isNative)
        .map((asset) {
          return tokenMap[asset.contractAddress] ??
              ChainBalance(
                chain: WalletChain.tron,
                symbol: asset.symbol,
                name: asset.name,
                amount: '0',
                address: address,
                contractAddress: asset.contractAddress,
                decimals: asset.decimals,
              );
        });
    final unknownTokens = tokenBalances.where((balance) {
      final contractAddress = balance.contractAddress;
      return contractAddress != null &&
          WalletAssetRegistry.findTronAsset(contractAddress) == null;
    });
    return [nativeBalance, ...knownTokens, ...unknownTokens];
  }

  Future<List<ChainBalance>> _loadSolanaBalances(String address) async {
    if (address.trim().isEmpty) {
      return _fallbackSolanaBalances(address);
    }

    final results = await Future.wait([
      _loadSolanaNativeBalance(address),
      ...WalletAssetRegistry.solanaAssets
          .where((asset) => !asset.isNative)
          .map((asset) => _loadSolanaTokenBalance(address, asset)),
    ]);
    return results;
  }

  List<ChainBalance> _fallbackSolanaBalances(String address) {
    return WalletAssetRegistry.solanaAssets
        .map(
          (asset) => ChainBalance(
            chain: WalletChain.solana,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: address,
            contractAddress: asset.contractAddress,
            decimals: asset.decimals,
          ),
        )
        .toList(growable: false);
  }

  Future<ChainBalance> _loadSolanaNativeBalance(String address) async {
    final asset = WalletAssetRegistry.solanaAssets.first;
    try {
      final data = await _postSolanaRpc(
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getBalance',
          'params': [address],
        },
      );
      final result = data['result'];
      final value = result is Map ? result['value'] : null;
      final lamports = value is int
          ? BigInt.from(value)
          : BigInt.tryParse(value?.toString() ?? '0') ?? BigInt.zero;
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(lamports, asset.decimals),
        address: address,
        decimals: asset.decimals,
      );
    } catch (e) {
      developer.log(
        'Solana native balance failed; using zero fallback: $e',
        name: 'ChainBalanceService',
      );
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
      );
    }
  }

  Future<ChainBalance> _loadSolanaTokenBalance(
    String address,
    WalletAsset asset,
  ) async {
    try {
      final data = await _postSolanaRpc(
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            address,
            {'mint': asset.contractAddress},
            {'encoding': 'jsonParsed'},
          ],
        },
      );
      final result = data['result'];
      final values = result is Map ? result['value'] : null;
      if (values is! List) {
        return ChainBalance(
          chain: WalletChain.solana,
          symbol: asset.symbol,
          name: asset.name,
          amount: '0',
          address: address,
          contractAddress: asset.contractAddress,
          decimals: asset.decimals,
        );
      }

      var rawAmountTotal = BigInt.zero;
      var decimals = asset.decimals;
      for (final item in values) {
        final account = item is Map ? item['account'] : null;
        final accountData = account is Map ? account['data'] : null;
        final parsed = accountData is Map ? accountData['parsed'] : null;
        final info = parsed is Map ? parsed['info'] : null;
        if (info is! Map) continue;

        final mint = info['mint']?.toString();
        if (mint != asset.contractAddress) continue;

        final tokenAmount = info['tokenAmount'];
        final decimalsValue = tokenAmount is Map ? tokenAmount['decimals'] : 0;
        decimals = decimalsValue is int
            ? decimalsValue
            : int.tryParse(decimalsValue?.toString() ?? '') ?? asset.decimals;
        final rawAmount = tokenAmount is Map
            ? tokenAmount['amount']?.toString()
            : null;
        rawAmountTotal += BigInt.tryParse(rawAmount ?? '0') ?? BigInt.zero;
      }
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(rawAmountTotal, decimals),
        address: address,
        contractAddress: asset.contractAddress,
        decimals: decimals,
      );
    } catch (e) {
      developer.log(
        'Solana ${asset.symbol} balance failed; using zero fallback: $e',
        name: 'ChainBalanceService',
      );
      return ChainBalance(
        chain: WalletChain.solana,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
      );
    }
  }

  Future<ChainBalance> _loadTronNativeBalance(String address) async {
    final asset = WalletAssetRegistry.tronAssets.first;
    try {
      final data = await _postTronAccount(address);
      final balance = data['balance'];
      final sun = balance is int
          ? BigInt.from(balance)
          : BigInt.tryParse(balance?.toString() ?? '0') ?? BigInt.zero;
      return ChainBalance(
        chain: WalletChain.tron,
        symbol: asset.symbol,
        name: asset.name,
        amount: _formatUnits(sun, asset.decimals),
        address: address,
        decimals: asset.decimals,
      );
    } catch (e) {
      return ChainBalance(
        chain: WalletChain.tron,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: e.toString(),
      );
    }
  }

  Future<List<ChainBalance>> _loadTronTokenBalances(String address) async {
    try {
      final response = await _dio.get(
        '${WalletChain.tron.rpcUrl}/v1/accounts/$address',
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is! Map ||
          data['data'] is! List ||
          (data['data'] as List).isEmpty) {
        return [];
      }
      final account = (data['data'] as List).first;
      if (account is! Map || account['trc20'] is! List) {
        return [];
      }
      final balances = <ChainBalance>[];
      for (final item in account['trc20'] as List) {
        if (item is! Map || item.isEmpty) continue;
        final contractAddress = item.keys.first.toString();
        final rawValue = item.values.first.toString();
        final asset = WalletAssetRegistry.findTronAsset(contractAddress);
        final decimals = asset?.decimals ?? 6;
        balances.add(
          ChainBalance(
            chain: WalletChain.tron,
            symbol: asset?.symbol ?? 'TRC20',
            name: asset?.name ?? contractAddress,
            amount: _formatUnits(
              BigInt.tryParse(rawValue) ?? BigInt.zero,
              decimals,
            ),
            address: address,
            contractAddress: contractAddress,
            decimals: decimals,
          ),
        );
      }
      return balances;
    } catch (_) {
      return WalletAssetRegistry.tronAssets
          .where((asset) => !asset.isNative)
          .map(
            (asset) => ChainBalance(
              chain: WalletChain.tron,
              symbol: asset.symbol,
              name: asset.name,
              amount: '0',
              address: address,
              contractAddress: asset.contractAddress,
              decimals: asset.decimals,
              error: 'TRC20 balance lookup failed',
            ),
          )
          .toList();
    }
  }

  static String erc20BalanceOfData(String address) {
    final cleanAddress = address.replaceFirst('0x', '').toLowerCase();
    return '0x70a08231${cleanAddress.padLeft(64, '0')}';
  }

  BigInt _parseHexQuantity(String value) {
    final cleanValue = value.replaceFirst('0x', '');
    if (cleanValue.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(cleanValue, radix: 16);
  }

  String _formatUnits(BigInt value, int decimals) {
    final base = BigInt.from(10).pow(decimals);
    final whole = value ~/ base;
    final fraction = value.remainder(base).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    if (trimmed.isEmpty) {
      return whole.toString();
    }
    return '$whole.$trimmed';
  }
}
