part of '../asset_valuation_service.dart';

/// Binance USDT 交易对行情源。
class _BinancePriceProvider extends AssetPriceProvider {
  _BinancePriceProvider(this._dio) : super('Binance');

  final Dio _dio;

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final tickerSymbols = requestedSymbols
        .map((symbol) => _binanceTickerSymbols[symbol])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (tickerSymbols.isEmpty) {
      return {};
    }

    try {
      final response = await _dio.get(
        'https://api.binance.com/api/v3/ticker/price',
        queryParameters: {'symbols': jsonEncode(tickerSymbols)},
      );
      return parsePrices(response.data, requestedSymbols);
    } catch (error) {
      final prices = <String, Decimal>{};
      for (final symbol in requestedSymbols) {
        final ticker = _binanceTickerSymbols[symbol];
        if (ticker == null) continue;
        try {
          final response = await _dio.get(
            'https://api.binance.com/api/v3/ticker/price',
            queryParameters: {'symbol': ticker},
          );
          prices.addAll(parsePrices(response.data, [symbol]));
        } catch (_) {
          // Continue with other symbols. The dispatcher will handle an empty result.
        }
      }
      if (prices.isEmpty) {
        throw AssetPriceProviderException(
          source: source,
          kind: AssetPriceFailureKind.requestFailed,
          cause: error,
        );
      }
      return prices;
    }
  }

  static Map<String, Decimal> parsePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    if (data is Map) {
      return parsePrices([data], requestedSymbols);
    }
    if (data is! List) {
      return {};
    }

    final normalizedSymbols = requestedSymbols
        .map((symbol) => symbol.toUpperCase())
        .toSet();
    final tickerPrices = <String, Decimal>{};
    for (final item in data) {
      if (item is! Map) continue;
      final ticker = item['symbol']?.toString();
      final price = Decimal.tryParse(item['price']?.toString() ?? '');
      if (ticker == null || price == null) continue;
      tickerPrices[ticker] = price;
    }

    return {
      for (final entry in _binanceTickerSymbols.entries)
        if (normalizedSymbols.contains(entry.key) &&
            tickerPrices[entry.value] != null)
          entry.key: tickerPrices[entry.value]!,
    };
  }
}
