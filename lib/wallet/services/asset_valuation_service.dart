import 'dart:convert';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../models/chain_balance.dart';

class AssetValuationService {
  AssetValuationService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
              headers: _requestHeaders,
            ),
          );

  final Dio _dio;
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _priceSourceTimeout = Duration(seconds: 4);
  static const Duration _priceCacheTtl = Duration(minutes: 1);
  static const Map<String, String> _requestHeaders = {
    'accept': 'application/json',
    'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  };

  static final Decimal _oneUsd = Decimal.one;
  static const Set<String> _stableSymbols = {
    'USDT',
    'USDC',
    'BUSD',
    'TUSD',
    'DAI',
  };
  static const Map<String, String> _binanceTickerSymbols = {
    'BNB': 'BNBUSDT',
    'TRX': 'TRXUSDT',
    'ETH': 'ETHUSDT',
    'BTCB': 'BTCUSDT',
    'WBTC': 'BTCUSDT',
    'OKB': 'OKBUSDT',
  };
  static const Map<String, String> _okxTickerSymbols = {
    'BNB': 'BNB-USDT',
    'TRX': 'TRX-USDT',
    'ETH': 'ETH-USDT',
    'BTCB': 'BTC-USDT',
    'WBTC': 'BTC-USDT',
    'OKB': 'OKB-USDT',
  };
  static const Map<String, String> _coingeckoIds = {
    'BNB': 'binancecoin',
    'TRX': 'tron',
    'ETH': 'ethereum',
    'BTCB': 'bitcoin',
    'WBTC': 'bitcoin',
    'OKB': 'okb',
  };
  static const Map<String, String> _cryptoCompareSymbols = {
    'BNB': 'BNB',
    'TRX': 'TRX',
    'ETH': 'ETH',
    'BTCB': 'BTC',
    'WBTC': 'BTC',
    'OKB': 'OKB',
  };
  static final Set<String> _pricedSymbols = {
    ..._okxTickerSymbols.keys,
    ..._coingeckoIds.keys,
    ..._binanceTickerSymbols.keys,
    ..._cryptoCompareSymbols.keys,
  };

  final Map<String, Decimal> _cachedUsdPrices = {};
  DateTime? _cachedUsdPricesAt;

  Map<String, Decimal> get cachedUsdPrices =>
      Map.unmodifiable(_cachedUsdPrices);

  bool get hasFreshCachedPrices {
    final cachedAt = _cachedUsdPricesAt;
    if (cachedAt == null || _cachedUsdPrices.isEmpty) {
      return false;
    }
    return DateTime.now().difference(cachedAt) < _priceCacheTtl;
  }

  Future<Decimal?> loadTotalUsdValue(List<ChainBalance> balances) async {
    Map<String, Decimal> prices;
    try {
      prices = await loadUsdPrices(balances);
    } catch (_) {
      prices = const {};
    }
    final total = calculateTotalUsdValue(balances, prices: prices);
    _logValuation(balances, prices, total);
    return total;
  }

  Future<Map<String, Decimal>> loadUsdPrices(
    List<ChainBalance> balances,
  ) async {
    final balanceSymbols = balances
        .map((balance) => balance.symbol.toUpperCase())
        .where((symbol) => !_stableSymbols.contains(symbol))
        .where(_pricedSymbols.contains)
        .toSet()
        .toList(growable: false);
    if (balanceSymbols.isEmpty) {
      return {};
    }

    return loadSupportedUsdPrices(balanceSymbols);
  }

  Future<Map<String, Decimal>> loadSupportedUsdPrices([
    Iterable<String>? symbols,
  ]) async {
    final requestedSymbols = (symbols ?? _pricedSymbols)
        .map((symbol) => symbol.toUpperCase())
        .where(_pricedSymbols.contains)
        .toSet()
        .toList(growable: false);
    if (requestedSymbols.isEmpty) {
      return cachedUsdPrices;
    }
    if (hasFreshCachedPrices &&
        requestedSymbols.every(_cachedUsdPrices.containsKey)) {
      return cachedUsdPrices;
    }

    final prices = <String, Decimal>{};

    final primaryResults = await Future.wait([
      _loadOkxUsdtPrices(
        requestedSymbols,
      ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
      _loadCryptoCompareUsdPrices(
        requestedSymbols,
      ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
      _loadCoinGeckoUsdPrices(
        requestedSymbols,
      ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
    ]);
    for (final result in primaryResults) {
      prices.addAll(result);
    }

    var missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    if (missingSymbols.isNotEmpty) {
      final binancePrices = await _loadBinanceUsdPrices(
        missingSymbols,
      ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{});
      prices.addAll(binancePrices);
    }

    if (prices.isNotEmpty) {
      _cachedUsdPrices.addAll(prices);
      _cachedUsdPricesAt = DateTime.now();
    }

    return cachedUsdPrices;
  }

  Future<Map<String, Decimal>> _loadBinanceUsdPrices(
    List<String> requestedSymbols,
  ) async {
    final tickerSymbols = requestedSymbols
        .map((symbol) => _binanceTickerSymbols[symbol])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (tickerSymbols.isEmpty) {
      return {};
    }

    final prices = <String, Decimal>{};

    try {
      final response = await _dio.get(
        'https://api.binance.com/api/v3/ticker/price',
        queryParameters: {'symbols': jsonEncode(tickerSymbols)},
      );
      prices.addAll(parseBinancePrices(response.data, requestedSymbols));
    } catch (error) {
      _logPriceSourceError('Binance batch', error);
      for (final symbol in requestedSymbols) {
        final ticker = _binanceTickerSymbols[symbol];
        if (ticker == null) continue;
        try {
          final response = await _dio.get(
            'https://api.binance.com/api/v3/ticker/price',
            queryParameters: {'symbol': ticker},
          );
          prices.addAll(parseBinancePrices(response.data, [symbol]));
        } catch (error) {
          _logPriceSourceError('Binance $symbol', error);
          // Keep trying other symbols and fallback sources.
        }
      }
    }

    return prices;
  }

  Future<Map<String, Decimal>> _loadOkxUsdtPrices(
    List<String> requestedSymbols,
  ) async {
    final prices = <String, Decimal>{};
    final symbolPrices = await Future.wait(
      requestedSymbols.map(_loadOkxSymbolPrice),
    );
    for (final price in symbolPrices) {
      prices.addAll(price);
    }

    final missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    if (missingSymbols.isNotEmpty) {
      try {
        final response = await _dio.get(
          'https://www.okx.com/api/v5/market/tickers',
          queryParameters: {'instType': 'SPOT'},
        );
        prices.addAll(parseOkxPrices(response.data, missingSymbols));
      } catch (error) {
        _logPriceSourceError('OKX all tickers', error);
        // Continue with fallback sources.
      }
    }

    return prices;
  }

  Future<Map<String, Decimal>> _loadOkxSymbolPrice(String symbol) async {
    final ticker = _okxTickerSymbols[symbol];
    if (ticker == null) {
      return {};
    }
    try {
      final response = await _dio.get(
        'https://www.okx.com/api/v5/market/ticker',
        queryParameters: {'instId': ticker},
      );
      return parseOkxPrices(response.data, [symbol]);
    } catch (error) {
      _logPriceSourceError('OKX $symbol', error);
      return {};
    }
  }

  Future<Map<String, Decimal>> _loadCryptoCompareUsdPrices(
    List<String> requestedSymbols,
  ) async {
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
      return parseCryptoComparePrices(response.data, requestedSymbols);
    } catch (error) {
      _logPriceSourceError('CryptoCompare', error);
      return {};
    }
  }

  Future<Map<String, Decimal>> _loadCoinGeckoUsdPrices(
    List<String> requestedSymbols,
  ) async {
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
      return parseCoinGeckoPrices(response.data, requestedSymbols);
    } catch (error) {
      _logPriceSourceError('CoinGecko', error);
      return {};
    }
  }

  Map<String, Decimal> parseBinancePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    if (data is Map) {
      return parseBinancePrices([data], requestedSymbols);
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

  Map<String, Decimal> parseOkxPrices(
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

  Map<String, Decimal> parseCoinGeckoPrices(
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

  Map<String, Decimal> parseCryptoComparePrices(
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

  Decimal? calculateTotalUsdValue(
    List<ChainBalance> balances, {
    Map<String, Decimal> prices = const {},
  }) {
    var total = Decimal.zero;
    var hasPricedAsset = false;

    for (final balance in balances) {
      final amount = Decimal.tryParse(balance.amount);
      final price = priceForSymbol(balance.symbol, prices);
      if (amount == null || price == null) continue;

      total += amount * price;
      hasPricedAsset = true;
    }

    return hasPricedAsset ? total : null;
  }

  Decimal? priceForSymbol(String symbol, Map<String, Decimal> prices) {
    final normalized = symbol.toUpperCase();
    if (_stableSymbols.contains(normalized)) {
      return _oneUsd;
    }
    return prices[normalized];
  }

  void _logValuation(
    List<ChainBalance> balances,
    Map<String, Decimal> prices,
    Decimal? total,
  ) {
    final buffer = StringBuffer()
      ..writeln('----- AssetValuationService.loadTotalUsdValue -----')
      ..writeln('prices=$prices')
      ..writeln('total=${total?.toStringAsFixed(8) ?? '-'}');

    for (final balance in balances) {
      final amount = Decimal.tryParse(balance.amount);
      final price = priceForSymbol(balance.symbol, prices);
      final value = amount == null || price == null ? null : amount * price;
      buffer.writeln(
        '${balance.chain.id}/${balance.symbol} '
        'amount=${balance.amount} parsedAmount=${amount?.toString() ?? '-'} '
        'price=${price?.toString() ?? '-'} '
        'value=${value?.toStringAsFixed(8) ?? '-'} '
        'error=${balance.error ?? '-'}',
      );
    }

    developer.log(buffer.toString(), name: 'AssetValuationService');
  }

  void _logPriceSourceError(String source, Object error) {
    developer.log(
      '$source price request failed: $error',
      name: 'AssetValuationService',
    );
  }

  String formatUsdValue(Decimal? value) {
    if (value == null) {
      return '--';
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}
