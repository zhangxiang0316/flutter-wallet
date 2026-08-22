import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../models/chain_balance.dart';

part 'asset_valuation/price_source_constants.dart';
part 'asset_valuation/price_provider.dart';
part 'asset_valuation/price_provider_dispatcher.dart';
part 'asset_valuation/binance_price_provider.dart';
part 'asset_valuation/okx_price_provider.dart';
part 'asset_valuation/coingecko_price_provider.dart';
part 'asset_valuation/defillama_price_provider.dart';
part 'asset_valuation/coinpaprika_price_provider.dart';
part 'asset_valuation/cryptocompare_price_provider.dart';

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
          ) {
    _priceProviderDispatcher = AssetPriceProviderDispatcher(
      primaryProviders: [
        _DefiLlamaPriceProvider(_dio),
        _CoinGeckoPriceProvider(_dio),
        _CoinPaprikaPriceProvider(_dio),
        _OkxPriceProvider(_dio),
      ],
      fallbackProviders: [
        _CryptoComparePriceProvider(_dio),
        _BinancePriceProvider(_dio),
      ],
      timeout: _priceSourceTimeout,
      onProviderResult: _logPriceSourceResult,
      onProviderError: _logPriceSourceError,
    );
  }

  /// 行情接口客户端。
  ///
  /// 这里只负责价格请求，不复用业务接口的 Dio，避免拦截器或 baseUrl 影响第三方接口。
  final Dio _dio;

  /// 统一调度多个价格源的查询顺序、超时和错误处理。
  late final AssetPriceProviderDispatcher _priceProviderDispatcher;

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

    _logPriceRequest(requestedSymbols);
    final prices = await _priceProviderDispatcher.load(requestedSymbols);

    // 只有拿到至少一个新价格时才刷新缓存时间，避免失败请求把旧缓存误标为新缓存。
    if (prices.isNotEmpty) {
      _cachedUsdPrices.addAll(prices);
      _cachedUsdPricesAt = DateTime.now();
    }

    _logPriceResult(requestedSymbols, prices);
    return cachedUsdPrices;
  }

  /// 解析 Binance ticker price 响应。
  ///
  /// 批量接口返回 List，单交易对接口返回 Map。这里统一转换成 List 后处理。
  /// 返回 key 使用应用内符号，而不是交易所交易对。
  Map<String, Decimal> parseBinancePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    return _BinancePriceProvider.parsePrices(data, requestedSymbols);
  }

  /// 解析 OKX ticker 响应。
  ///
  /// OKX 返回的 `instId` 是 `ETH-USDT` 这类交易对，需要通过 [_okxTickerSymbols]
  /// 反查回应用内符号。
  Map<String, Decimal> parseOkxPrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    return _OkxPriceProvider.parsePrices(data, requestedSymbols);
  }

  /// 解析 CoinGecko simple price 响应。
  ///
  /// 响应结构通常是 `{ ethereum: { usd: 1234.56 } }`。
  Map<String, Decimal> parseCoinGeckoPrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    return _CoinGeckoPriceProvider.parsePrices(data, requestedSymbols);
  }

  /// 解析 DeFiLlama 当前价格响应。
  ///
  /// 响应结构通常是 `{ coins: { "coingecko:ethereum": { price: ... } } }`。
  Map<String, Decimal> parseDefiLlamaPrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    return _DefiLlamaPriceProvider.parsePrices(data, requestedSymbols);
  }

  /// 解析 CoinPaprika ticker 响应。
  ///
  /// 单个资产接口返回 Map，批量兼容场景可能传入 List，这里都按列表处理。
  /// USD 价格位于 `quotes.USD.price`。
  Map<String, Decimal> parseCoinPaprikaPrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    return _CoinPaprikaPriceProvider.parsePrices(data, requestedSymbols);
  }

  /// 解析 CryptoCompare 多币种价格响应。
  ///
  /// 响应结构通常是 `{ ETH: { USD: 1234.56 } }`。
  Map<String, Decimal> parseCryptoComparePrices(
    dynamic data,
    Iterable<String> requestedSymbols,
  ) {
    return _CryptoComparePriceProvider.parsePrices(data, requestedSymbols);
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
