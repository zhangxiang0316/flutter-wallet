import 'package:dio/dio.dart';

import '../../models/wallet_chain.dart';

/// 单个 RPC 节点健康检查结果。
class WalletRpcHealthResult {
  const WalletRpcHealthResult({
    required this.rpcUrl,
    required this.isAvailable,
    this.latencyMs,
    this.error,
  });

  /// RPC URL。
  final String rpcUrl;

  /// 当前节点是否可用。
  final bool isAvailable;

  /// 请求耗时，单位毫秒。不可用时为空。
  final int? latencyMs;

  /// 不可用时的错误摘要。
  final String? error;
}

/// 某条链的 RPC 健康检查结果。
class WalletChainRpcHealthReport {
  const WalletChainRpcHealthReport({
    required this.chainId,
    required this.results,
    required this.checkedAt,
  });

  /// 钱包链 ID。
  final String chainId;

  /// 每个 RPC 的检测结果。
  final List<WalletRpcHealthResult> results;

  /// 检测时间。
  final DateTime checkedAt;

  WalletRpcHealthResult? get primaryResult {
    return results.isEmpty ? null : results.first;
  }

  WalletRpcHealthResult? get bestAvailableResult {
    final available =
        results
            .where((result) => result.isAvailable && result.latencyMs != null)
            .toList(growable: false)
          ..sort((left, right) => left.latencyMs!.compareTo(right.latencyMs!));
    return available.isEmpty ? null : available.first;
  }

  bool get hasAvailableRpc => bestAvailableResult != null;
}

/// RPC 健康检查服务。
class WalletRpcHealthService {
  WalletRpcHealthService({Dio? dio})
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

  static const Duration _requestTimeout = Duration(seconds: 5);

  /// 检测某条链配置中的所有 RPC。
  Future<WalletChainRpcHealthReport> checkChain(WalletChainConfig chain) async {
    final results = <WalletRpcHealthResult>[];
    for (final rpcUrl in chain.rpcUrls) {
      results.add(await checkRpc(chain: chain, rpcUrl: rpcUrl));
    }
    return WalletChainRpcHealthReport(
      chainId: chain.id,
      results: results,
      checkedAt: DateTime.now(),
    );
  }

  /// 检测单个 RPC。
  Future<WalletRpcHealthResult> checkRpc({
    required WalletChainConfig chain,
    required String rpcUrl,
  }) async {
    final normalizedUrl = rpcUrl.trim();
    if (normalizedUrl.isEmpty) {
      return const WalletRpcHealthResult(
        rpcUrl: '',
        isAvailable: false,
        error: 'Empty RPC URL',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      await switch (chain.type) {
        WalletChainType.evm => _checkEvmRpc(chain, normalizedUrl),
        WalletChainType.solana => _checkSolanaRpc(normalizedUrl),
        WalletChainType.tron => _checkTronRpc(normalizedUrl),
        WalletChainType.bitcoin => _checkBitcoinApi(normalizedUrl),
      };
      stopwatch.stop();
      return WalletRpcHealthResult(
        rpcUrl: normalizedUrl,
        isAvailable: true,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (error) {
      stopwatch.stop();
      return WalletRpcHealthResult(
        rpcUrl: normalizedUrl,
        isAvailable: false,
        error: error.toString(),
      );
    }
  }

  Future<void> _checkEvmRpc(WalletChainConfig chain, String rpcUrl) async {
    final response = await _dio.post(
      rpcUrl,
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
    if (result is! String || !result.startsWith('0x')) {
      throw StateError('Invalid EVM RPC response');
    }
    final chainId = int.parse(result.substring(2), radix: 16);
    final expectedChainId = chain.evmChainId;
    if (expectedChainId != null && chainId != expectedChainId) {
      throw StateError('RPC chain ID mismatch');
    }
  }

  Future<void> _checkSolanaRpc(String rpcUrl) async {
    final response = await _dio.post(
      rpcUrl,
      data: {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getHealth',
        'params': const [],
      },
      options: Options(headers: {'content-type': 'application/json'}),
    );
    final data = response.data;
    final result = data is Map ? data['result'] : null;
    if (result != 'ok') {
      throw StateError('Invalid Solana RPC response');
    }
  }

  Future<void> _checkTronRpc(String rpcUrl) async {
    final response = await _dio.post('$rpcUrl/wallet/getnowblock');
    final data = response.data;
    if (data is! Map || data['block_header'] == null) {
      throw StateError('Invalid TRON RPC response');
    }
  }

  Future<void> _checkBitcoinApi(String apiUrl) async {
    final response = await _dio.get('$apiUrl/blocks/tip/height');
    if (int.tryParse(response.data?.toString() ?? '') == null) {
      throw StateError('Invalid Bitcoin API response');
    }
  }
}
