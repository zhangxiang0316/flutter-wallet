import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';

class _FakePriceProvider extends AssetPriceProvider {
  _FakePriceProvider(
    super.source, {
    Map<String, Decimal>? prices,
    this.delay = Duration.zero,
    this.error,
  }) : prices = Map.of(prices ?? const {});

  final Map<String, Decimal> prices;
  final Duration delay;
  final Object? error;
  final List<List<String>> requests = [];

  @override
  Future<Map<String, Decimal>> load(List<String> requestedSymbols) async {
    requests.add(List.of(requestedSymbols));
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (error != null) {
      throw error!;
    }
    return {
      for (final symbol in requestedSymbols)
        if (prices.containsKey(symbol)) symbol: prices[symbol]!,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetPriceProviderDispatcher', () {
    test('queries primary providers concurrently in batches', () async {
      final provider1 = _FakePriceProvider(
        'P1',
        prices: {'A': Decimal.parse('1')},
      );
      final provider2 = _FakePriceProvider(
        'P2',
        prices: {'B': Decimal.parse('2')},
      );
      final provider3 = _FakePriceProvider(
        'P3',
        prices: {'C': Decimal.parse('3')},
      );
      final dispatcher = AssetPriceProviderDispatcher(
        primaryProviders: [provider1, provider2, provider3],
        fallbackProviders: [],
        timeout: const Duration(seconds: 5),
        onProviderResult: (_, __, ___) {},
        onProviderError: (_, __) {},
      );

      final result = await dispatcher.load(['A', 'B', 'C']);

      expect(result['A'], Decimal.parse('1'));
      expect(result['B'], Decimal.parse('2'));
      expect(result['C'], Decimal.parse('3'));
      expect(provider1.requests.single, ['A', 'B', 'C']);
      expect(provider2.requests.single, ['A', 'B', 'C']);
      expect(provider3.requests.single, ['C']);
    });

    test(
      'does not call fallback providers when primary covers everything',
      () async {
        final primary = _FakePriceProvider(
          'P1',
          prices: {'BTC': Decimal.parse('60000')},
        );
        final fallback = _FakePriceProvider(
          'F1',
          prices: {'BTC': Decimal.parse('999')},
        );
        final dispatcher = AssetPriceProviderDispatcher(
          primaryProviders: [primary],
          fallbackProviders: [fallback],
          timeout: const Duration(seconds: 5),
          onProviderResult: (_, __, ___) {},
          onProviderError: (_, __) {},
        );

        final result = await dispatcher.load(['BTC']);

        expect(result['BTC'], Decimal.parse('60000'));
        expect(fallback.requests, isEmpty);
      },
    );

    test(
      'aggregates missing symbols from parallel fallback providers',
      () async {
        final fallback1 = _FakePriceProvider(
          'F1',
          prices: {'A': Decimal.parse('10')},
        );
        final fallback2 = _FakePriceProvider(
          'F2',
          prices: {'B': Decimal.parse('20')},
        );
        final dispatcher = AssetPriceProviderDispatcher(
          primaryProviders: [],
          fallbackProviders: [fallback1, fallback2],
          timeout: const Duration(seconds: 5),
          onProviderResult: (_, __, ___) {},
          onProviderError: (_, __) {},
        );

        final result = await dispatcher.load(['A', 'B']);

        expect(result['A'], Decimal.parse('10'));
        expect(result['B'], Decimal.parse('20'));
        expect(fallback1.requests.single, containsAll(['A', 'B']));
        expect(fallback2.requests.single, containsAll(['A', 'B']));
      },
    );

    test(
      'skips later batches when the first batch resolves all symbols',
      () async {
        final provider1 = _FakePriceProvider(
          'P1',
          prices: {'A': Decimal.parse('1'), 'B': Decimal.parse('2')},
        );
        final provider2 = _FakePriceProvider(
          'P2',
          prices: {'B': Decimal.parse('99')},
        );
        final provider3 = _FakePriceProvider(
          'P3',
          prices: {'A': Decimal.parse('9'), 'B': Decimal.parse('9')},
        );
        final dispatcher = AssetPriceProviderDispatcher(
          primaryProviders: [provider1, provider2, provider3],
          fallbackProviders: [],
          timeout: const Duration(seconds: 5),
          onProviderResult: (_, __, ___) {},
          onProviderError: (_, __) {},
        );

        final result = await dispatcher.load(['A', 'B']);

        expect(result['A'], Decimal.parse('1'));
        expect(result['B'], Decimal.parse('2'));
        expect(provider2.requests.single, ['A', 'B']);
        expect(provider3.requests, isEmpty);
      },
    );

    test(
      'keeps the first price by provider order within a concurrent batch',
      () async {
        final provider1 = _FakePriceProvider(
          'P1',
          prices: {'BTC': Decimal.parse('60000')},
        );
        final provider2 = _FakePriceProvider(
          'P2',
          prices: {'BTC': Decimal.parse('70000')},
        );
        final dispatcher = AssetPriceProviderDispatcher(
          primaryProviders: [provider1, provider2],
          fallbackProviders: [],
          timeout: const Duration(seconds: 5),
          onProviderResult: (_, __, ___) {},
          onProviderError: (_, __) {},
        );

        final result = await dispatcher.load(['BTC']);

        expect(result['BTC'], Decimal.parse('60000'));
        expect(provider2.requests.single, ['BTC']);
      },
    );
  });
}
