import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// RPC 请求重试助手。
///
/// 封装通用的 RPC 请求重试逻辑，支持多个 RPC 节点自动 fallback。
class RpcRetryHelper {
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

        throw StateError('Invalid response structure from $rpcUrl');
      } catch (error) {
        lastError = error;
        developer.log(
          '$chainName RPC request failed at $rpcUrl',
          error: error,
          name: 'RpcRetryHelper',
        );
      }
    }

    throw StateError(
      'All $chainName RPC nodes failed. Last error: $lastError',
    );
  }

  /// 发送 JSON-RPC POST 请求的便捷方法。
  ///
  /// 封装了 Dio POST 请求和标准 JSON-RPC 格式。
  static Future<Map<String, dynamic>> executeJsonRpc({
    required Dio dio,
    required List<String> rpcUrls,
    required String method,
    required List<dynamic> params,
    required String chainName,
    Map<String, String>? headers,
  }) async {
    return execute<Map<String, dynamic>>(
      rpcUrls: rpcUrls,
      chainName: chainName,
      request: (rpcUrl) async {
        final response = await dio.post(
          rpcUrl,
          data: {
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          },
          options: Options(
            headers: headers ?? {'content-type': 'application/json'},
          ),
        );
        return response.data as Map<String, dynamic>;
      },
      validator: (response) {
        // 标准 JSON-RPC 响应应包含 result 或 error
        return response.containsKey('result') || response.containsKey('error');
      },
    );
  }
}
