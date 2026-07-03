part of '../asset_valuation_service.dart';

/// OKX 现货 USDT 交易对行情源。
class _OkxPriceProvider extends AssetPriceProvider {
  _OkxPriceProvider(this._dio) : super('OKX');

  final Dio _dio;

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final prices = <String, Decimal>{};
    Object? firstError;

    try {
      final response = await _dio.get(
        'https://www.okx.com/api/v5/market/tickers',
        queryParameters: {'instType': 'SPOT'},
      );
      prices.addAll(parsePrices(response.data, requestedSymbols));
    } catch (error) {
      firstError = error;
    }

    final missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    if (missingSymbols.isNotEmpty) {
      final symbolPrices = await Future.wait(
        missingSymbols.map(_loadSymbolPrice),
      );
      for (final price in symbolPrices) {
        prices.addAll(price);
      }
    }

    if (prices.isEmpty && firstError != null) {
      throw AssetPriceProviderException(
        source: source,
        kind: AssetPriceFailureKind.requestFailed,
        cause: firstError,
      );
    }
    return prices;
  }

  Future<Map<String, Decimal>> _loadSymbolPrice(String symbol) async {
    final ticker = _okxTickerSymbols[symbol];
    if (ticker == null) {
      return {};
    }
    try {
      final response = await _dio.get(
        'https://www.okx.com/api/v5/market/ticker',
        queryParameters: {'instId': ticker},
      );
      return parsePrices(response.data, [symbol]);
    } catch (_) {
      return {};
    }
  }

  static Map<String, Decimal> parsePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    if (data is! Map || data['data'] is! List) {
      return {};
    }

    final normalizedSymbols = requestedSymbols
        .map((symbol) => symbol.toUpperCase())
        .toSet();
    final tickerPrices = <String, Decimal>{};
    for (final item in data['data'] as List) {
      if (item is! Map) continue;
      final ticker = item['instId']?.toString();
      final price = Decimal.tryParse(item['last']?.toString() ?? '');
      if (ticker == null || price == null) continue;
      tickerPrices[ticker] = price;
    }

    return {
      for (final entry in _okxTickerSymbols.entries)
        if (normalizedSymbols.contains(entry.key) &&
            tickerPrices[entry.value] != null)
          entry.key: tickerPrices[entry.value]!,
    };
  }
}
