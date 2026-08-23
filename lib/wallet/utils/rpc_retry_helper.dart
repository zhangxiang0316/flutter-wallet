import 'package:dio/dio.dart';

import '../../utils/safe_log.dart';

/// RPC 请求重试助手。
///
/// 封装通用的 RPC 请求重试逻辑，支持多个 RPC 节点自动 fallback。
class RpcRetryHelper {
  /// 合并主 RPC 和备用 RPC，按顺序去重并过滤空值。
  static List<String> mergeRpcUrls(
    List<String> primary,
    List<String> fallback,
  ) {
    final values = <String>{};
    for (final url in [...primary, ...fallback]) {
      final normalized = url.trim();
      if (normalized.isNotEmpty) {
        values.add(normalized);
      }
    }
    return values.toList(growable: false);
  }

  /// 发送带重试的 RPC 请求。
  ///
  /// [rpcUrls] 是按优先级排序的 RPC 节点列表。
  /// [request] 是实际发送请求的函数，接收一个 RPC URL 并返回响应。
  /// [validator] 验证响应是否有效，返回 true 表示成功。
  /// [chainName] 用于日志记录。
  ///
  /// 该方法会依次尝试所有 RPC 节点，直到找到一个成功的响应或全部失败。
  static Future<T> execute<T>({
    required List<String> rpcUrls,
    required Future<T> Function(String rpcUrl) request,
    required bool Function(T response) validator,
    required String chainName,
    String operation = 'RPC request',
    String logName = 'RpcRetryHelper',
    Object Function(String rpcUrl, T response)? invalidResponseError,
  }) async {
    if (rpcUrls.isEmpty) {
      throw StateError('No RPC URLs provided for $chainName');
    }

    Object? lastError;

    for (final rpcUrl in rpcUrls) {
      try {
        final response = await request(rpcUrl);

        if (validator(response)) {
          return response;
        }

        throw invalidResponseError?.call(rpcUrl, response) ??
            StateError('Invalid response structure from $rpcUrl');
      } catch (error) {
        lastError = error;
        SafeLog.error(
          '$chainName $operation failed at $rpcUrl',
          error: error,
          name: logName,
        );
      }
    }

    throw StateError(
      'All $chainName RPC nodes failed for $operation. '
      'Last error: $lastError',
    );
  }

  /// 发送 JSON-RPC POST 请求的便捷方法。
  ///
  /// 封装了 Dio POST 请求和标准 JSON-RPC 格式。
  static Future<Map<dynamic, dynamic>> executeJsonRpc({
    required Dio dio,
    required List<String> rpcUrls,
    required String method,
    required List<dynamic> params,
    required String chainName,
    String logName = 'RpcRetryHelper',
    bool Function(Object? error)? returnErrorWhen,
    Map<String, String>? headers,
    Options? options,
  }) async {
    return execute<Map<dynamic, dynamic>>(
      rpcUrls: rpcUrls,
      chainName: chainName,
      operation: method,
      logName: logName,
      request: (rpcUrl) async {
        final response = await dio.post(
          rpcUrl,
          data: {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params},
          options:
              options ??
              Options(headers: headers ?? {'content-type': 'application/json'}),
        );
        final data = response.data;
        if (data is Map) {
          return data;
        }
        throw StateError('Invalid $chainName RPC response');
      },
      validator: (response) {
        if (response.containsKey('result')) {
          return true;
        }
        if (response.containsKey('error')) {
          return returnErrorWhen?.call(response['error']) ?? false;
        }
        return false;
      },
      invalidResponseError: (rpcUrl, response) {
        if (response.containsKey('error')) {
          return StateError('$chainName RPC error: ${response['error']}');
        }
        return StateError('Invalid $chainName RPC response');
      },
    );
  }
}
