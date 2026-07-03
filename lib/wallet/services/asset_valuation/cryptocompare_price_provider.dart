part of '../asset_valuation_service.dart';

/// CryptoCompare USD 多币种行情源。
class _CryptoComparePriceProvider extends AssetPriceProvider {
  _CryptoComparePriceProvider(this._dio) : super('CryptoCompare');

  final Dio _dio;

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    final symbols = requestedSymbols
        .map((symbol) => _cryptoCompareSymbols[symbol])
        .whereType<String>()
        .toSet()
        .join(',');
    if (symbols.isEmpty) {
      return {};
    }

    try {
      final response = await _dio.get(
        'https://min-api.cryptocompare.com/data/pricemulti',
        queryParameters: {'fsyms': symbols, 'tsyms': 'USD'},
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
      final ticker = _cryptoCompareSymbols[symbol];
      final item = ticker == null ? null : data[ticker];
      if (item is! Map) continue;
      final price = Decimal.tryParse(item['USD']?.toString() ?? '');
      if (price == null) continue;
      prices[symbol] = price;
    }
    return prices;
  }
}
