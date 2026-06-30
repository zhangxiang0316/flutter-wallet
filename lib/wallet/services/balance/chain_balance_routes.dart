part of '../chain_balance_service.dart';

extension _ChainBalanceRoutes on ChainBalanceService {
  Future<Map<dynamic, dynamic>> _postEvmRpc({
    required WalletChainRef chain,
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
      return _rpcUrlsWithFallbacks(
        chain.rpcUrls,
        ChainBalanceService._evmRpcFallbacks[chain.builtinChain] ?? const [],
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

  /// 合并用户配置 RPC 与内置备用 RPC，并保持顺序去重。
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

  /// 返回 TRON 链可尝试的 HTTP/RPC 地址。
  List<String> _tronRpcUrls(WalletChainConfig chain) {
    return _rpcUrlsWithFallbacks(
      chain.rpcUrls,
      ChainBalanceService._tronRpcFallbacks,
    );
  }

  /// 返回 Solana 链可尝试的 JSON-RPC 地址。
  List<String> _solanaRpcUrls(WalletChainConfig chain) {
    return _rpcUrlsWithFallbacks(
      chain.rpcUrls,
      ChainBalanceService._solanaRpcFallbacks,
    );
  }

  /// 查询 TRON 账号基础信息。
  ///
  /// 返回数据里包含 TRX 原生余额。TRC20 列表使用另一个 HTTP API 查询。
  Future<Map<dynamic, dynamic>> _postTronAccount(
    WalletChainConfig chain,
    String address,
  ) async {
    Object? lastError;
    for (final rpcUrl in _tronRpcUrls(chain)) {
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

  /// 向 Solana 节点发送 JSON-RPC 请求。
  ///
  /// Solana 使用更短的单请求超时，并在多个公共节点之间 fallback。
  Future<Map<dynamic, dynamic>> _postSolanaRpc({
    required WalletChainConfig chain,
    required Map<String, dynamic> data,
    bool Function(Object? error)? returnErrorWhen,
  }) async {
    Object? lastError;
    for (final rpcUrl in _solanaRpcUrls(chain)) {
      try {
        final response = await _dio.post(
          rpcUrl,
          data: data,
          options: Options(
            headers: {'content-type': 'application/json'},
            connectTimeout: ChainBalanceService._solanaRequestTimeout,
            sendTimeout: ChainBalanceService._solanaRequestTimeout,
            receiveTimeout: ChainBalanceService._solanaRequestTimeout,
          ),
        );
        final responseData = response.data;
        if (responseData is Map && responseData['result'] != null) {
          return responseData;
        }
        if (responseData is Map && responseData['error'] != null) {
          final rpcError = responseData['error'];
          if (returnErrorWhen?.call(rpcError) ?? false) {
            return responseData;
          }
          throw StateError('Solana RPC error: $rpcError');
        }
        throw StateError('Invalid Solana RPC response');
      } catch (error) {
        lastError = error;
        final method = data['method']?.toString() ?? 'unknown';
        developer.log(
          'Solana RPC $method request failed at $rpcUrl: $error',
          name: 'ChainBalanceService',
        );
      }
    }
    throw StateError(
      'Solana RPC request failed: ${lastError ?? 'unknown error'}',
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
}
