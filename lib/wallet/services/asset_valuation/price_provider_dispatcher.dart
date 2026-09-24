part of '../asset_valuation_service.dart';

typedef AssetPriceProviderResultLogger =
    void Function(
      String source,
      List<String> requestedSymbols,
      Map<String, Decimal> prices,
    );

typedef AssetPriceProviderErrorLogger =
    void Function(String source, Object error);

/// 统一调度行情源的查询顺序、fallback、超时和日志。
class AssetPriceProviderDispatcher {
  const AssetPriceProviderDispatcher({
    required this.primaryProviders,
    required this.fallbackProviders,
    required this.timeout,
    required this.onProviderResult,
    required this.onProviderError,
  });

  final List<AssetPriceProvider> primaryProviders;
  final List<AssetPriceProvider> fallbackProviders;
  final Duration timeout;
  final AssetPriceProviderResultLogger onProviderResult;
  final AssetPriceProviderErrorLogger onProviderError;

  static const int _primaryBatchSize = 2;

  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final prices = <String, Decimal>{};

    for (
      var offset = 0;
      offset < primaryProviders.length;
      offset += _primaryBatchSize
    ) {
      final missingSymbols = _missingSymbols(requestedSymbols, prices);
      if (missingSymbols.isEmpty) {
        break;
      }

      final batch = primaryProviders
          .skip(offset)
          .take(_primaryBatchSize)
          .toList(growable: false);
      final results = await Future.wait(
        batch.map((provider) => _loadProvider(provider, missingSymbols)),
      );

      // Future.wait 保留 batch 顺序；先添加的来源优先，和原有串行 fallback
      // 语义一致，同时允许同一批来源并发完成。
      for (final result in results) {
        for (final entry in result.entries) {
          prices.putIfAbsent(entry.key, () => entry.value);
        }
      }
    }

    final missingSymbols = _missingSymbols(requestedSymbols, prices);
    if (missingSymbols.isNotEmpty) {
      final fallbackResults = await Future.wait(
        fallbackProviders.map(
          (provider) => _loadProvider(provider, missingSymbols),
        ),
      );
      for (final result in fallbackResults) {
        prices.addAll(result);
      }
    }

    return prices;
  }

  Future<Map<String, Decimal>> _loadProvider(
    AssetPriceProvider provider,
    List<String> requestedSymbols,
  ) async {
    if (requestedSymbols.isEmpty) {
      return {};
    }
    try {
      final result = await provider
          .load(requestedSymbols)
          .timeout(
            timeout,
            onTimeout: () {
              throw AssetPriceProviderException(
                source: provider.source,
                kind: AssetPriceFailureKind.timeout,
                cause: TimeoutException(
                  '${provider.source} price source timeout',
                ),
              );
            },
          );
      onProviderResult(provider.source, requestedSymbols, result);
      return result;
    } catch (error) {
      onProviderError(provider.source, error);
      onProviderResult(provider.source, requestedSymbols, const {});
      return {};
    }
  }

  List<String> _missingSymbols(
    List<String> requestedSymbols,
    Map<String, Decimal> prices,
  ) {
    return requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
  }
}
