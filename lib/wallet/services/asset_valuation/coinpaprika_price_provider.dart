part of '../asset_valuation_service.dart';

/// CoinPaprika ticker 行情源。
class _CoinPaprikaPriceProvider extends AssetPriceProvider {
  _CoinPaprikaPriceProvider(this._dio) : super('CoinPaprika');

  final Dio _dio;

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final symbolsById = <String, List<String>>{};
    for (final symbol in requestedSymbols) {
      final id = _coinPaprikaIds[symbol];
      if (id == null) continue;
      symbolsById.putIfAbsent(id, () => <String>[]).add(symbol);
    }
    if (symbolsById.isEmpty) {
      return {};
    }

    Object? firstError;
    final symbolPrices = await Future.wait(
      symbolsById.entries.map((entry) async {
        try {
          return await _loadAssetPrice(
            assetId: entry.key,
            symbols: entry.value,
          );
        } catch (error) {
          firstError ??= error;
          return <String, Decimal>{};
        }
      }),
    );
    final prices = {for (final item in symbolPrices) ...item};
    if (prices.isEmpty && firstError != null) {
      throw AssetPriceProviderException(
        source: source,
        kind: AssetPriceFailureKind.requestFailed,
        cause: firstError!,
      );
    }
    return prices;
  }

  Future<Map<String, Decimal>> _loadAssetPrice({
    required String assetId,
    required List<String> symbols,
  }) async {
    final response = await _dio.get(
      'https://api.coinpaprika.com/v1/tickers/$assetId',
    );
    return parsePrices(response.data, symbols);
  }

  static Map<String, Decimal> parsePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    final items = data is List ? data : [data];
    final tickerPrices = <String, Decimal>{};
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id']?.toString();
      final quotes = item['quotes'];
      final usdQuote = quotes is Map ? quotes['USD'] : null;
      final price = usdQuote is Map
          ? Decimal.tryParse(usdQuote['price']?.toString() ?? '')
          : null;
      if (id == null || price == null) continue;
      tickerPrices[id] = price;
    }

    final normalizedSymbols = requestedSymbols
        .map((symbol) => symbol.toUpperCase())
        .toSet();
    return {
      for (final entry in _coinPaprikaIds.entries)
        if (normalizedSymbols.contains(entry.key) &&
            tickerPrices[entry.value] != null)
          entry.key: tickerPrices[entry.value]!,
    };
  }
}
