part of '../asset_valuation_service.dart';

/// 行情源失败类型。
enum AssetPriceFailureKind {
  /// 请求失败、响应异常或解析不到有效数据。
  requestFailed,

  /// 单个行情源超时。
  timeout,
}

/// 行情源统一错误对象。
class AssetPriceProviderException implements Exception {
  const AssetPriceProviderException({
    required this.source,
    required this.kind,
    required this.cause,
  });

  final String source;
  final AssetPriceFailureKind kind;
  final Object cause;

  @override
  String toString() {
    return 'AssetPriceProviderException(source: $source, '
        'kind: ${kind.name}, cause: $cause)';
  }
}

/// 单个行情源 Provider。
abstract class AssetPriceProvider {
  const AssetPriceProvider(this.source);

  final String source;

  Future<Map<String, Decimal>> load(List<String> requestedSymbols);
}
