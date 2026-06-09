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
  static final Decimal _minimumDisplayValue = Decimal.parse('0.01');
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
    'SOL': 'SOLUSDT',
  };
  static const Map<String, String> _okxTickerSymbols = {
    'BNB': 'BNB-USDT',
    'TRX': 'TRX-USDT',
    'ETH': 'ETH-USDT',
    'BTCB': 'BTC-USDT',
    'WBTC': 'BTC-USDT',
    'OKB': 'OKB-USDT',
    'SOL': 'SOL-USDT',
  };
  static const Map<String, String> _coingeckoIds = {
    'BNB': 'binancecoin',
    'TRX': 'tron',
    'ETH': 'ethereum',
    'BTCB': 'bitcoin',
    'WBTC': 'bitcoin',
    'OKB': 'okb',
    'SOL': 'solana',
  };
  static const Map<String, String> _coinPaprikaIds = {
    'BNB': 'bnb-binance-coin',
    'TRX': 'trx-tron',
    'ETH': 'eth-ethereum',
    'BTCB': 'btc-bitcoin',
    'WBTC': 'btc-bitcoin',
    'OKB': 'okb-okb',
    'SOL': 'sol-solana',
  };
  static const Map<String, String> _cryptoCompareSymbols = {
    'BNB': 'BNB',
    'TRX': 'TRX',
    'ETH': 'ETH',
    'BTCB': 'BTC',
    'WBTC': 'BTC',
    'OKB': 'OKB',
    'SOL': 'SOL',
  };
  static final Set<String> _pricedSymbols = {
    ..._okxTickerSymbols.keys,
    ..._coingeckoIds.keys,
    ..._coinPaprikaIds.keys,
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
    _logPriceRequest(requestedSymbols);

    await _mergePriceSource(
      prices,
      source: 'DeFiLlama',
      requestedSymbols: requestedSymbols,
      loader: _loadDefiLlamaUsdPrices,
    );
    await _mergePriceSource(
      prices,
      source: 'CoinGecko',
      requestedSymbols: _missingSymbols(requestedSymbols, prices),
      loader: _loadCoinGeckoUsdPrices,
    );
    await _mergePriceSource(
      prices,
      source: 'CoinPaprika',
      requestedSymbols: _missingSymbols(requestedSymbols, prices),
      loader: _loadCoinPaprikaUsdPrices,
    );
    await _mergePriceSource(
      prices,
      source: 'OKX',
      requestedSymbols: _missingSymbols(requestedSymbols, prices),
      loader: _loadOkxUsdtPrices,
    );

    var missingSymbols = _missingSymbols(requestedSymbols, prices);
    if (missingSymbols.isNotEmpty) {
      final fallbackResults = await Future.wait([
        _loadCryptoCompareUsdPrices(
          missingSymbols,
        ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
        _loadBinanceUsdPrices(
          missingSymbols,
        ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
      ]);
      for (final result in fallbackResults) {
        prices.addAll(result);
      }
    }

    if (prices.isNotEmpty) {
      _cachedUsdPrices.addAll(prices);
      _cachedUsdPricesAt = DateTime.now();
    }

    _logPriceResult(requestedSymbols, prices);
    return cachedUsdPrices;
  }

  Future<void> _mergePriceSource(
    Map<String, Decimal> prices, {
    required String source,
    required List<String> requestedSymbols,
    required Future<Map<String, Decimal>> Function(List<String> symbols) loader,
  }) async {
    if (requestedSymbols.isEmpty) {
      return;
    }
    final result = await loader(
      requestedSymbols,
    ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{});
    if (result.isNotEmpty) {
      prices.addAll(result);
    }
    _logPriceSourceResult(source, requestedSymbols, result);
  }

  List<String> _missingSymbols(
    List<String> requestedSymbols,
    Map<String, Decimal> prices,
  ) {
    return requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
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
    try {
      final response = await _dio.get(
        'https://www.okx.com/api/v5/market/tickers',
        queryParameters: {'instType': 'SPOT'},
      );
      prices.addAll(parseOkxPrices(response.data, requestedSymbols));
    } catch (error) {
      _logPriceSourceError('OKX all tickers', error);
    }

    var missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
    if (missingSymbols.isNotEmpty) {
      final symbolPrices = await Future.wait(
        missingSymbols.map(
          (symbol) => _loadOkxSymbolPrice(
            symbol,
          ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
        ),
      );
      for (final price in symbolPrices) {
        prices.addAll(price);
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

  Future<Map<String, Decimal>> _loadDefiLlamaUsdPrices(
    List<String> requestedSymbols,
  ) async {
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
      return parseDefiLlamaPrices(response.data, requestedSymbols);
    } catch (error) {
      _logPriceSourceError('DeFiLlama', error);
      return {};
    }
  }

  Future<Map<String, Decimal>> _loadCoinPaprikaUsdPrices(
    List<String> requestedSymbols,
  ) async {
    final symbolsById = <String, List<String>>{};
    for (final symbol in requestedSymbols) {
      final id = _coinPaprikaIds[symbol];
      if (id == null) continue;
      symbolsById.putIfAbsent(id, () => <String>[]).add(symbol);
    }
    if (symbolsById.isEmpty) {
      return {};
    }

    final symbolPrices = await Future.wait(
      symbolsById.entries.map(
        (entry) => _loadCoinPaprikaAssetPrice(
          assetId: entry.key,
          symbols: entry.value,
        ).timeout(_priceSourceTimeout, onTimeout: () => <String, Decimal>{}),
      ),
    );
    return {for (final prices in symbolPrices) ...prices};
  }

  Future<Map<String, Decimal>> _loadCoinPaprikaAssetPrice({
    required String assetId,
    required List<String> symbols,
  }) async {
    try {
      final response = await _dio.get(
        'https://api.coinpaprika.com/v1/tickers/$assetId',
      );
      return parseCoinPaprikaPrices(response.data, symbols);
    } catch (error) {
      _logPriceSourceError('CoinPaprika $assetId', error);
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

  Map<String, Decimal> parseDefiLlamaPrices(
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

  Map<String, Decimal> parseCoinPaprikaPrices(
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

  String? formatNonStableUsdValue(
    ChainBalance balance, {
    Map<String, Decimal> prices = const {},
  }) {
    if (isStableSymbol(balance.symbol)) {
      return null;
    }

    final amount = Decimal.tryParse(balance.amount);
    if (amount == null) {
      return '≈ -- USDT';
    }
    if (amount == Decimal.zero) {
      return '≈ 0.00 USDT';
    }

    final price = priceForSymbol(balance.symbol, prices);
    if (price == null) {
      return '≈ -- USDT';
    }
    return '≈ ${formatStableEquivalent(amount * price)} USDT';
  }

  String formatStableEquivalent(Decimal value) {
    if (value == Decimal.zero) {
      return '0.00';
    }
    if (value.compareTo(_minimumDisplayValue) < 0) {
      return value.toStringAsFixed(6);
    }
    return value.toStringAsFixed(2);
  }

  bool isStableSymbol(String symbol) {
    return _stableSymbols.contains(symbol.toUpperCase());
  }

  Decimal? priceForSymbol(String symbol, Map<String, Decimal> prices) {
    final normalized = symbol.toUpperCase();
    if (isStableSymbol(normalized)) {
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

  void _logPriceRequest(List<String> requestedSymbols) {
    developer.log(
      'requesting USD prices for ${requestedSymbols.join(', ')}',
      name: 'AssetValuationService',
    );
  }

  void _logPriceSourceResult(
    String source,
    List<String> requestedSymbols,
    Map<String, Decimal> prices,
  ) {
    developer.log(
      '$source requested=${requestedSymbols.join(', ')} '
      'prices=$prices',
      name: 'AssetValuationService',
    );
  }

  void _logPriceResult(
    List<String> requestedSymbols,
    Map<String, Decimal> prices,
  ) {
    final missingSymbols = requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .join(', ');
    developer.log(
      'resolved USD prices=$prices missing=${missingSymbols.isEmpty ? '-' : missingSymbols}',
      name: 'AssetValuationService',
    );
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
