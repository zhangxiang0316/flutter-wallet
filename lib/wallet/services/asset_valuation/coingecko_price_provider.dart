part of '../asset_valuation_service.dart';

/// CoinGecko simple price 行情源。
class _CoinGeckoPriceProvider extends AssetPriceProvider {
  _CoinGeckoPriceProvider(this._dio) : super('CoinGecko');

  final Dio _dio;

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final ids = requestedSymbols
        .map((symbol) => _coingeckoIds[symbol])
        .whereType<String>()
        .toSet()
        .join(',');
    if (ids.isEmpty) {
      return {};
    }

    try {
      final response = await _dio.get(
        'https://api.coingecko.com/api/v3/simple/price',
        queryParameters: {'ids': ids, 'vs_currencies': 'usd'},
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
    if (data is! Map) {
      return {};
    }

    final prices = <String, Decimal>{};
    for (final symbol in requestedSymbols.map((value) => value.toUpperCase())) {
      final id = _coingeckoIds[symbol];
      final item = id == null ? null : data[id];
      if (item is! Map) continue;
      final price = Decimal.tryParse(item['usd']?.toString() ?? '');
      if (price == null) continue;
      prices[symbol] = price;
    }
    return prices;
  }
}
