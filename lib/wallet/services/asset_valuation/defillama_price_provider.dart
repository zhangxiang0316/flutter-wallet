part of '../asset_valuation_service.dart';

/// DeFiLlama current price 行情源。
class _DefiLlamaPriceProvider extends AssetPriceProvider {
  _DefiLlamaPriceProvider(this._dio) : super('DeFiLlama');

  final Dio _dio;

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final coins = requestedSymbols
        .map((symbol) => _coingeckoIds[symbol])
        .whereType<String>()
        .map((id) => 'coingecko:$id')
        .toSet()
        .join(',');
    if (coins.isEmpty) {
      return {};
    }

    try {
      final response = await _dio.get(
        'https://coins.llama.fi/prices/current/$coins',
      );
      return parsePrices(response.data, requestedSymbols);
    } catch (error) {
      throw AssetPriceProviderException(
        source: source,
        kind: AssetPriceFailureKind.requestFailed,
        cause: error,
      );
    }
  }

  static Map<String, Decimal> parsePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    if (data is! Map || data['coins'] is! Map) {
      return {};
    }

    final coinPrices = <String, Decimal>{};
    final coins = data['coins'] as Map;
    for (final entry in coins.entries) {
      final key = entry.key.toString();
      final item = entry.value;
      if (item is! Map) continue;
      final price = Decimal.tryParse(item['price']?.toString() ?? '');
      if (price == null) continue;
      coinPrices[key] = price;
    }

    final normalizedSymbols = requestedSymbols
        .map((symbol) => symbol.toUpperCase())
        .toSet();
    return {
      for (final entry in _coingeckoIds.entries)
        if (normalizedSymbols.contains(entry.key) &&
            coinPrices['coingecko:${entry.value}'] != null)
          entry.key: coinPrices['coingecko:${entry.value}']!,
    };
  }
}
