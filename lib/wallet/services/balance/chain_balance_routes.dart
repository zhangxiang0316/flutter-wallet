part of '../chain_balance_service.dart';

extension _ChainBalanceRoutes on ChainBalanceService {
  Future<Map<dynamic, dynamic>> _postEvmRpc({
    required WalletChainRef chain,
    required Map<String, dynamic> data,
  }) async {
    return RpcRetryHelper.execute<Map<dynamic, dynamic>>(
      rpcUrls: _evmRpcUrls(chain),
      chainName: chain.name,
      operation: data['method']?.toString() ?? 'EVM RPC',
      logName: 'ChainBalanceService',
      request: (rpcUrl) async {
        final response = await _dio.post(
          rpcUrl,
          data: data,
          options: Options(headers: {'content-type': 'application/json'}),
        );
        final responseData = response.data;
        if (responseData is Map) {
          return responseData;
        }
        throw StateError('Invalid ${chain.name} RPC response');
      },
      validator: (responseData) => responseData['result'] is String,
      invalidResponseError: (_, responseData) {
        if (responseData['error'] != null) {
          return StateError(
            '${chain.name} RPC error: ${responseData['error']}',
          );
        }
        return StateError('Invalid ${chain.name} RPC response');
      },
    );
  }

  /// 返回某条 EVM 链可用的 RPC 地址列表。
  List<String> _evmRpcUrls(WalletChainRef chain) {
    if (chain is WalletChainConfig && !chain.isBuiltin) {
      return chain.rpcUrls;
    }
    if (chain is WalletChain &&
        ChainBalanceService._evmRpcFallbacks.containsKey(chain)) {
      return ChainBalanceService._evmRpcFallbacks[chain]!;
    }
    if (chain is WalletChainConfig && chain.builtinChain != null) {
      return RpcRetryHelper.mergeRpcUrls(
        ChainBalanceService._evmRpcFallbacks[chain.builtinChain] ?? const [],
        chain.rpcUrls,
      );
    }
    return [chain.rpcUrl];
  }

  /// 从启用链列表中取内置链配置。
  ///
  /// 正常情况下内置链一定存在；兜底返回 enum 默认配置，避免本地配置异常时中断余额刷新。
  WalletChainConfig _builtinChainConfig(
    List<WalletChainConfig> chains,
    WalletChain builtin,
  ) {
    for (final chain in chains) {
      if (chain.builtinChain == builtin || chain.id == builtin.id) {
        return chain;
      }
    }
    return builtin.config;
  }

  /// 返回 TRON 链可尝试的 HTTP/RPC 地址。
  List<String> _tronRpcUrls(WalletChainConfig chain) {
    return RpcRetryHelper.mergeRpcUrls(
      chain.rpcUrls,
      ChainBalanceService._tronRpcFallbacks,
    );
  }

  /// 返回 Solana 链可尝试的 JSON-RPC 地址。
  List<String> _solanaRpcUrls(WalletChainConfig chain) {
    final heliusRpcUrl = _heliusSolanaRpcUrl();
    return RpcRetryHelper.mergeRpcUrls([
      if (heliusRpcUrl != null) heliusRpcUrl,
      ...ChainBalanceService._solanaRpcFallbacks,
    ], chain.rpcUrls);
  }

  String? _heliusSolanaRpcUrl() {
    final apiKey = _apiConfig.heliusApiKey.trim();
    if (apiKey.isEmpty) return null;
    return 'https://mainnet.helius-rpc.com/?api-key=${Uri.encodeQueryComponent(apiKey)}';
  }

  /// 查询 TRON 账号基础信息。
  ///
  /// 返回数据里包含 TRX 原生余额。TRC20 列表使用另一个 HTTP API 查询。
  Future<Map<dynamic, dynamic>> _postTronAccount(
    WalletChainConfig chain,
    String address,
  ) async {
    return RpcRetryHelper.execute<Map<dynamic, dynamic>>(
      rpcUrls: _tronRpcUrls(chain),
      chainName: 'TRON',
      operation: 'account request',
      logName: 'ChainBalanceService',
      request: (rpcUrl) async {
        final response = await _dio.post(
          '$rpcUrl/wallet/getaccount',
          data: {'address': address, 'visible': true},
          options: Options(headers: _tronHeaders(rpcUrl)),
        );
        final responseData = response.data;
        if (responseData is Map) {
          return responseData;
        }
        throw StateError('Invalid TRON response');
      },
      validator: (responseData) =>
          responseData['Error'] == null && responseData['error'] == null,
      invalidResponseError: (_, responseData) {
        return StateError(
          'TRON RPC error: ${responseData['Error'] ?? responseData['error']}',
        );
      },
    );
  }

  Map<String, String> _tronHeaders(String rpcUrl) {
    final apiKey = _apiConfig.tronGridApiKey.trim();
    return {
      'content-type': 'application/json',
      if (apiKey.isNotEmpty && rpcUrl.contains('trongrid.io'))
        'TRON-PRO-API-KEY': apiKey,
    };
  }

  /// 向 Solana 节点发送 JSON-RPC 请求。
  ///
  /// Solana 使用更短的单请求超时，并在多个公共节点之间 fallback。
  Future<Map<dynamic, dynamic>> _postSolanaRpc({
    required WalletChainConfig chain,
    required Map<String, dynamic> data,
    bool Function(Object? error)? returnErrorWhen,
  }) async {
    return RpcRetryHelper.execute<Map<dynamic, dynamic>>(
      rpcUrls: _solanaRpcUrls(chain),
      chainName: 'Solana',
      operation: data['method']?.toString() ?? 'RPC request',
      logName: 'ChainBalanceService',
      request: (rpcUrl) async {
        final response = await _dio
            .post(
              rpcUrl,
              data: data,
              options: Options(
                headers: {'content-type': 'application/json'},
                connectTimeout: ChainBalanceService._solanaRequestTimeout,
                sendTimeout: ChainBalanceService._solanaRequestTimeout,
                receiveTimeout: ChainBalanceService._solanaRequestTimeout,
              ),
            )
            .timeout(ChainBalanceService._solanaRequestTimeout);
        final responseData = response.data;
        if (responseData is Map) {
          return responseData;
        }
        throw StateError('Invalid Solana RPC response');
      },
      validator: (responseData) {
        if (responseData['result'] != null) {
          return true;
        }
        if (responseData['error'] != null) {
          return returnErrorWhen?.call(responseData['error']) ?? false;
        }
        return false;
      },
      invalidResponseError: (_, responseData) {
        if (responseData['error'] != null) {
          return StateError('Solana RPC error: ${responseData['error']}');
        }
        return StateError('Invalid Solana RPC response');
      },
    );
  }

  /// 打印本次余额加载的详细日志。
  ///
  /// 用于排查“某条链一直 loading”或“某个币种余额不对”的问题，会输出每条链、
  /// 每个币种的数量、精度、合约地址和错误信息。
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
          : chainBalances.first.chainRef.name;
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

  /// 查询某条 EVM 链下所有默认资产和自定义资产余额。
  List<ChainBalance> _fallbackBalancesForAssets({
    required WalletChainConfig chain,
    required List<WalletAsset> assets,
    required String address,
    required String error,
  }) {
    return assets
        .map(
          (asset) => ChainBalance.config(
            chainConfig: chain,
            symbol: asset.symbol,
            name: asset.name,
            amount: '0',
            address: address,
            contractAddress: asset.contractAddress,
            logoUrl: asset.logoUrl,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
            error: error,
          ),
        )
        .toList(growable: false);
  }
}
