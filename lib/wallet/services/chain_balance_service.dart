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

  Future<List<ChainBalance>> loadBalances({
    required String bscAddress,
    required String tronAddress,
  }) async {
    final results = await Future.wait([
      _loadEvmBalances(
        chain: WalletChain.bsc,
        assets: WalletAssetRegistry.bscAssets,
        address: bscAddress,
      ),
      _loadEvmBalances(
        chain: WalletChain.xLayer,
        assets: WalletAssetRegistry.xLayerAssets,
        address: bscAddress,
      ),
      _loadTronBalances(tronAddress),
    ]);
    final balances = results.expand((items) => items).toList();
    _printLoadedBalances(results, balances);
    return balances;
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
      final response = await _dio.post(
        chain.rpcUrl,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
          'id': 1,
        },
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is Map && data['result'] is String) {
        final wei = BigInt.parse(
          (data['result'] as String).replaceFirst('0x', ''),
          radix: 16,
        );
        return ChainBalance(
          chain: chain,
          symbol: asset.symbol,
          name: asset.name,
          amount: _formatUnits(wei, asset.decimals),
          address: address,
          decimals: asset.decimals,
        );
      }
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: 'Invalid ${chain.name} response',
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
      final response = await _dio.post(
        chain.rpcUrl,
        data: {
          'jsonrpc': '2.0',
          'method': 'eth_call',
          'params': [
            {'to': asset.contractAddress, 'data': erc20BalanceOfData(address)},
            'latest',
          ],
          'id': 1,
        },
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is Map && data['result'] is String) {
        final result = (data['result'] as String).replaceFirst('0x', '');
        final value = result.isEmpty
            ? BigInt.zero
            : BigInt.parse(result, radix: 16);
        return ChainBalance(
          chain: chain,
          symbol: asset.symbol,
          name: asset.name,
          amount: _formatUnits(value, asset.decimals),
          address: address,
          contractAddress: asset.contractAddress,
          decimals: asset.decimals,
        );
      }
      return ChainBalance(
        chain: chain,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        contractAddress: asset.contractAddress,
        decimals: asset.decimals,
        error: 'Invalid ${chain.name} token response',
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

  Future<ChainBalance> _loadTronNativeBalance(String address) async {
    final asset = WalletAssetRegistry.tronAssets.first;
    try {
      final response = await _dio.post(
        '${WalletChain.tron.rpcUrl}/wallet/getaccount',
        data: {'address': address, 'visible': true},
        options: Options(headers: {'content-type': 'application/json'}),
      );
      final data = response.data;
      if (data is Map) {
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
      }
      return ChainBalance(
        chain: WalletChain.tron,
        symbol: asset.symbol,
        name: asset.name,
        amount: '0',
        address: address,
        decimals: asset.decimals,
        error: 'Invalid TRON response',
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
