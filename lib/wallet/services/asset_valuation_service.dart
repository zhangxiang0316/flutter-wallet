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
  };

  Future<Decimal?> loadTotalUsdValue(List<ChainBalance> balances) async {
    final prices = await loadUsdPrices(balances);
    return calculateTotalUsdValue(balances, prices: prices);
  }

  Future<Map<String, Decimal>> loadUsdPrices(
    List<ChainBalance> balances,
  ) async {
    final tickerSymbols = balances
        .map((balance) => _binanceTickerSymbols[balance.symbol.toUpperCase()])
        .whereType<String>()
        .toSet()
        .toList();
    if (tickerSymbols.isEmpty) {
      return {};
    }

    try {
      final response = await _dio.get(
        'https://api.binance.com/api/v3/ticker/price',
        queryParameters: {'symbols': jsonEncode(tickerSymbols)},
      );
      final data = response.data;
      if (data is! List) {
        return {};
      }

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
          if (tickerPrices[entry.value] != null)
            entry.key: tickerPrices[entry.value]!,
      };
    } catch (_) {
      return {};
    }
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
