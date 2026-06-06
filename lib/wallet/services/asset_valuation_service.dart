import 'dart:convert';

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
            ),
          );

  final Dio _dio;
  static const Duration _requestTimeout = Duration(seconds: 8);

  static final Decimal _oneUsd = Decimal.one;
  static const Set<String> _stableSymbols = {'USDT', 'USDC', 'BUSD', 'TUSD'};
  static const Map<String, String> _binanceTickerSymbols = {
    'BNB': 'BNBUSDT',
    'TRX': 'TRXUSDT',
    'ETH': 'ETHUSDT',
    'BTCB': 'BTCUSDT',
    'OKB': 'OKBUSDT',
  };
  static const Map<String, String> _okxTickerSymbols = {
    'BNB': 'BNB-USDT',
    'TRX': 'TRX-USDT',
    'ETH': 'ETH-USDT',
    'BTCB': 'BTC-USDT',
    'OKB': 'OKB-USDT',
  };
  static const Map<String, String> _coingeckoIds = {
    'BNB': 'binancecoin',
    'TRX': 'tron',
    'ETH': 'ethereum',
    'BTCB': 'bitcoin',
    'OKB': 'okb',
  };
  static final Set<String> _pricedSymbols = {
    ..._okxTickerSymbols.keys,
    ..._coingeckoIds.keys,
    ..._binanceTickerSymbols.keys,
  };

  Future<Decimal?> loadTotalUsdValue(List<ChainBalance> balances) async {
    final prices = await loadUsdPrices(balances);
    return calculateTotalUsdValue(balances, prices: prices);
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

    // Load the complete supported price set once a priced asset exists. This
    // avoids missing valuation when a chain request returns zero/error rows
    // before the specific non-stable balance has refreshed.
    final requestedSymbols = _pricedSymbols.toList(growable: false);
    final prices = <String, Decimal>{};
    prices.addAll(await _loadOkxUsdtPrices(requestedSymbols));

    var missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    if (missingSymbols.isNotEmpty) {
      prices.addAll(await _loadCoinGeckoUsdPrices(missingSymbols));
    }

    missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    if (missingSymbols.isNotEmpty) {
      prices.addAll(await _loadBinanceUsdPrices(missingSymbols));
    }

    return prices;
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
    } catch (_) {
      for (final symbol in requestedSymbols) {
        final ticker = _binanceTickerSymbols[symbol];
        if (ticker == null) continue;
        try {
          final response = await _dio.get(
            'https://api.binance.com/api/v3/ticker/price',
            queryParameters: {'symbol': ticker},
          );
          prices.addAll(parseBinancePrices(response.data, [symbol]));
        } catch (_) {
          // Keep trying other symbols and fallback sources.
        }
      }
    }

    return prices;
  }

  Future<Map<String, Decimal>> _loadOkxUsdtPrices(
    List<String> requestedSymbols,
  ) async {
    final tickerSymbols = requestedSymbols
        .map((symbol) => _okxTickerSymbols[symbol])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    if (tickerSymbols.isEmpty) {
      return {};
    }

    final prices = <String, Decimal>{};
    try {
      final response = await _dio.get(
        'https://www.okx.com/api/v5/market/tickers',
        queryParameters: {'instType': 'SPOT'},
      );
      prices.addAll(parseOkxPrices(response.data, requestedSymbols));
    } catch (_) {
      // Fall through to per-symbol requests.
    }

    final missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    for (final symbol in missingSymbols) {
      final ticker = _okxTickerSymbols[symbol];
      if (ticker == null) continue;
      try {
        final response = await _dio.get(
          'https://www.okx.com/api/v5/market/ticker',
          queryParameters: {'instId': ticker},
        );
        prices.addAll(parseOkxPrices(response.data, [symbol]));
      } catch (_) {
        // Continue with other symbols and fallback sources.
      }
    }

    return prices;
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
    } catch (_) {
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

  String formatUsdValue(Decimal? value) {
    if (value == null) {
      return '--';
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}
