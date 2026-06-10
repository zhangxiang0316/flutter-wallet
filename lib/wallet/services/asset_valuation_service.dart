import 'dart:convert';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../models/chain_balance.dart';

/// 资产 USD 估值服务。
///
/// 首页总资产、单个非稳定币折算值都依赖这个服务。服务做三件事：
/// 1. 根据余额列表提取需要实时询价的币种；
/// 2. 通过多个公开行情源获取这些币种的 USD/USDT 价格，并做短时间缓存；
/// 3. 将链上余额数量和价格相乘，得到稳定币口径的估值。
///
/// 稳定币（USDT/USDC/BUSD/TUSD/DAI）不走外部接口，直接按 1 USD 计算。
/// 非稳定币如果价格源都失败，会在估值时跳过，避免用错误价格污染总资产。
class AssetValuationService {
  /// 创建估值服务。
  ///
  /// 测试时可以注入自定义 [Dio]，业务代码默认使用内置超时和请求头配置。
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

  /// 行情接口客户端。
  ///
  /// 这里只负责价格请求，不复用业务接口的 Dio，避免拦截器或 baseUrl 影响第三方接口。
  final Dio _dio;

  /// 单个 HTTP 请求的整体超时时间。
  static const Duration _requestTimeout = Duration(seconds: 8);

  /// 单个价格源允许占用的最大时间。
  ///
  /// 首页刷新余额时会同步刷新估值，价格接口不能无限等待，否则会拖慢首页展示。
  static const Duration _priceSourceTimeout = Duration(seconds: 4);

  /// 价格缓存有效期。
  ///
  /// 钱包余额会定时刷新，价格短时间内变化不需要每次都重新请求所有行情源。
  static const Duration _priceCacheTtl = Duration(minutes: 1);

  /// 第三方行情接口请求头。
  ///
  /// 部分公开接口会拒绝缺少 user-agent 的请求，这里使用移动端浏览器 UA 提高兼容性。
  static const Map<String, String> _requestHeaders = {
    'accept': 'application/json',
    'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1',
  };

  /// 稳定币固定使用的 USD 单价。
  static final Decimal _oneUsd = Decimal.one;

  /// 小额估值展示阈值。
  ///
  /// 小于 0.01 时保留 6 位小数，否则用户会看到 0.00，误以为资产完全没有价值。
  static final Decimal _minimumDisplayValue = Decimal.parse('0.01');

  /// 直接按 1 USD 计算的稳定币符号集合。
  static const Set<String> _stableSymbols = {
    'USDT',
    'USDC',
    'BUSD',
    'TUSD',
    'DAI',
  };

  /// Binance 现货接口使用的交易对映射。
  ///
  /// 应用内符号和交易所交易对不完全一致，例如 BTCB/WBTC 都需要映射到 BTCUSDT。
  static const Map<String, String> _binanceTickerSymbols = {
    'BNB': 'BNBUSDT',
    'TRX': 'TRXUSDT',
    'ETH': 'ETHUSDT',
    'BTCB': 'BTCUSDT',
    'WBTC': 'BTCUSDT',
    'OKB': 'OKBUSDT',
    'SOL': 'SOLUSDT',
  };

  /// OKX 现货接口使用的交易对映射。
  static const Map<String, String> _okxTickerSymbols = {
    'BNB': 'BNB-USDT',
    'TRX': 'TRX-USDT',
    'ETH': 'ETH-USDT',
    'BTCB': 'BTC-USDT',
    'WBTC': 'BTC-USDT',
    'OKB': 'OKB-USDT',
    'SOL': 'SOL-USDT',
  };

  /// CoinGecko/DeFiLlama 使用的币种 ID 映射。
  ///
  /// DeFiLlama 的价格接口使用 `coingecko:<id>` 作为 key，所以两者共用这份映射。
  static const Map<String, String> _coingeckoIds = {
    'BNB': 'binancecoin',
    'TRX': 'tron',
    'ETH': 'ethereum',
    'BTCB': 'bitcoin',
    'WBTC': 'bitcoin',
    'OKB': 'okb',
    'SOL': 'solana',
  };

  /// CoinPaprika 使用的币种 ID 映射。
  static const Map<String, String> _coinPaprikaIds = {
    'BNB': 'bnb-binance-coin',
    'TRX': 'trx-tron',
    'ETH': 'eth-ethereum',
    'BTCB': 'btc-bitcoin',
    'WBTC': 'btc-bitcoin',
    'OKB': 'okb-okb',
    'SOL': 'sol-solana',
  };

  /// CryptoCompare 接口使用的币种符号映射。
  static const Map<String, String> _cryptoCompareSymbols = {
    'BNB': 'BNB',
    'TRX': 'TRX',
    'ETH': 'ETH',
    'BTCB': 'BTC',
    'WBTC': 'BTC',
    'OKB': 'OKB',
    'SOL': 'SOL',
  };

  /// 当前服务可以尝试获取实时价格的非稳定币集合。
  ///
  /// 如果后续新增币种，需要至少在一个价格源映射中加入符号，才会进入询价流程。
  static final Set<String> _pricedSymbols = {
    ..._okxTickerSymbols.keys,
    ..._coingeckoIds.keys,
    ..._coinPaprikaIds.keys,
    ..._binanceTickerSymbols.keys,
    ..._cryptoCompareSymbols.keys,
  };

  /// 最近一次成功解析到的 USD 价格缓存。
  ///
  /// key 是应用内统一的大写币种符号，value 是该币种的 USD 单价。
  final Map<String, Decimal> _cachedUsdPrices = {};

  /// 价格缓存写入时间，用于判断是否仍在 TTL 内。
  DateTime? _cachedUsdPricesAt;

  /// 对外暴露只读缓存，供首页在余额刷新之外复用最近一次价格。
  Map<String, Decimal> get cachedUsdPrices =>
      Map.unmodifiable(_cachedUsdPrices);

  /// 当前缓存是否仍可直接使用。
  bool get hasFreshCachedPrices {
    final cachedAt = _cachedUsdPricesAt;
    if (cachedAt == null || _cachedUsdPrices.isEmpty) {
      return false;
    }
    return DateTime.now().difference(cachedAt) < _priceCacheTtl;
  }

  /// 拉取价格并计算总资产 USD 估值。
  ///
  /// 价格请求失败时不向外抛错，而是使用空价格表继续计算。这样首页不会因为
  /// 第三方行情接口异常而进入错误状态，最多显示为 `--` 或只统计稳定币。
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

  /// 根据余额列表拉取所需非稳定币价格。
  ///
  /// 这里只会提取服务已支持的非稳定币符号。稳定币无需询价，自定义但未配置
  /// 价格源的币种也不会请求，避免无意义的网络调用。
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

  /// 拉取指定币种集合的 USD 价格。
  ///
  /// [symbols] 为空时会尝试加载全部支持的非稳定币价格。请求顺序为：
  /// DeFiLlama -> CoinGecko -> CoinPaprika -> OKX -> CryptoCompare/Binance。
  /// 前面的来源没返回的币种才会继续向后查询，减少请求量和接口限流风险。
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

    // 优先使用覆盖面较广且接口返回结构稳定的聚合价格源。
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

    // 最后的 fallback 并行请求两个交易所/数据源，缩短缺失价格的等待时间。
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

    // 只有拿到至少一个新价格时才刷新缓存时间，避免失败请求把旧缓存误标为新缓存。
    if (prices.isNotEmpty) {
      _cachedUsdPrices.addAll(prices);
      _cachedUsdPricesAt = DateTime.now();
    }

    _logPriceResult(requestedSymbols, prices);
    return cachedUsdPrices;
  }

  /// 合并单个价格源的查询结果。
  ///
  /// 该方法统一处理单源超时和日志记录。具体接口异常由各 loader 内部吞掉，
  /// 这里主要负责把结果叠加到当前价格表。
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

  /// 返回尚未从任何价格源解析到价格的币种。
  List<String> _missingSymbols(
    List<String> requestedSymbols,
    Map<String, Decimal> prices,
  ) {
    return requestedSymbols
        .where((symbol) => !prices.containsKey(symbol))
        .toList(growable: false);
  }

  /// 从 Binance 读取 USDT 交易对价格。
  ///
  /// 先尝试批量接口；如果批量请求失败，再按单个交易对逐个重试。这样 Binance
  /// 对某些地区或参数格式返回错误时，仍有机会拿到部分币种价格。
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
    // OKX 全量现货 ticker 可以一次覆盖多个交易对，先用它减少请求次数。
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

    // 全量接口没覆盖到的交易对，再用单交易对接口补查。
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

  /// 从 OKX 单交易对接口读取一个币种价格。
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

  /// 从 CryptoCompare 读取 USD 报价。
  ///
  /// CryptoCompare 支持一次传入多个符号，返回形如 `{ BTC: { USD: ... } }`。
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

  /// 从 CoinGecko simple price 接口读取 USD 报价。
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

  /// 从 DeFiLlama 当前价格接口读取 USD 报价。
  ///
  /// DeFiLlama 使用 `coingecko:<id>` 作为资产标识，因此复用 [_coingeckoIds]。
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

  /// 从 CoinPaprika 按资产 ID 并发读取 USD 报价。
  ///
  /// 多个应用内符号可能指向同一个底层资产，例如 BTCB/WBTC 都按 BTC 价格处理。
  /// 因此这里先按 CoinPaprika assetId 分组，再将同一价格回填给多个符号。
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

  /// 请求 CoinPaprika 单个资产详情并解析为应用内符号价格。
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

  /// 解析 Binance ticker price 响应。
  ///
  /// 批量接口返回 List，单交易对接口返回 Map。这里统一转换成 List 后处理。
  /// 返回 key 使用应用内符号，而不是交易所交易对。
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

  /// 解析 OKX ticker 响应。
  ///
  /// OKX 返回的 `instId` 是 `ETH-USDT` 这类交易对，需要通过 [_okxTickerSymbols]
  /// 反查回应用内符号。
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

  /// 解析 CoinGecko simple price 响应。
  ///
  /// 响应结构通常是 `{ ethereum: { usd: 1234.56 } }`。
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

  /// 解析 DeFiLlama 当前价格响应。
  ///
  /// 响应结构通常是 `{ coins: { "coingecko:ethereum": { price: ... } } }`。
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

  /// 解析 CoinPaprika ticker 响应。
  ///
  /// 单个资产接口返回 Map，批量兼容场景可能传入 List，这里都按列表处理。
  /// USD 价格位于 `quotes.USD.price`。
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

  /// 解析 CryptoCompare 多币种价格响应。
  ///
  /// 响应结构通常是 `{ ETH: { USD: 1234.56 } }`。
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

  /// 计算余额列表的总 USD 估值。
  ///
  /// 每个余额先解析数量，再通过 [priceForSymbol] 找价格。无法解析数量或没有价格
  /// 的资产会被跳过；如果所有资产都无法估值，则返回 null，让 UI 显示 `--`。
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

  /// 格式化非稳定币对应的稳定币估值文案。
  ///
  /// 稳定币自身不需要展示“折算值”，因此直接返回 null。
  /// 非稳定币没有价格时返回 `≈ -- USDT`，避免误展示为 0。
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

  /// 格式化稳定币口径金额。
  ///
  /// 常规金额保留 2 位小数；小于 0.01 的金额保留 6 位，避免小额资产被截成 0.00。
  String formatStableEquivalent(Decimal value) {
    if (value == Decimal.zero) {
      return '0.00';
    }
    if (value.compareTo(_minimumDisplayValue) < 0) {
      return value.toStringAsFixed(6);
    }
    return value.toStringAsFixed(2);
  }

  /// 判断符号是否为稳定币。
  bool isStableSymbol(String symbol) {
    return _stableSymbols.contains(symbol.toUpperCase());
  }

  /// 获取某个币种的 USD 单价。
  ///
  /// 稳定币直接返回 1，非稳定币从传入的价格表中查找。传入价格表通常来自
  /// [loadSupportedUsdPrices] 或 [cachedUsdPrices]。
  Decimal? priceForSymbol(String symbol, Map<String, Decimal> prices) {
    final normalized = symbol.toUpperCase();
    if (isStableSymbol(normalized)) {
      return _oneUsd;
    }
    return prices[normalized];
  }

  /// 打印估值过程日志。
  ///
  /// 该日志用于排查“总资产不对”这类问题，会列出每个资产的原始数量、
  /// 解析后的数量、匹配到的价格、计算出的价值以及链上查询错误。
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

  /// 打印本次需要请求价格的币种列表。
  void _logPriceRequest(List<String> requestedSymbols) {
    developer.log(
      'requesting USD prices for ${requestedSymbols.join(', ')}',
      name: 'AssetValuationService',
    );
  }

  /// 打印单个价格源的返回结果。
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

  /// 打印所有价格源合并后的最终结果。
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

  /// 打印单个价格源请求失败的错误。
  ///
  /// 行情源失败不会中断整体估值，只记录日志并继续尝试其他来源。
  void _logPriceSourceError(String source, Object error) {
    developer.log(
      '$source price request failed: $error',
      name: 'AssetValuationService',
    );
  }

  /// 格式化首页展示的总 USD 金额。
  String formatUsdValue(Decimal? value) {
    if (value == null) {
      return '--';
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}
