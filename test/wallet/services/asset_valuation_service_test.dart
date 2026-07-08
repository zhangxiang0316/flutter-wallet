import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssetValuationService', () {
    late AssetValuationService service;

    setUp(() {
      service = AssetValuationService();
    });

    test('calculates total value from stable assets and injected prices', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '10.25',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.tron,
            symbol: 'USDC',
            name: 'USD Coin',
            amount: '5',
            address: 'T1',
          ),
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BNB',
            name: 'BNB',
            amount: '2',
            address: '0x1',
          ),
        ],
        prices: {'BNB': Decimal.parse('300')},
      );

      expect(total?.toStringAsFixed(2), '615.25');
      expect(service.formatUsdValue(total), r'$615.25');
    });

    test('calculates BTCB value with mapped BTC price', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BTCB',
            name: 'Bitcoin BEP2',
            amount: '0.01',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.tron,
            symbol: 'TRX',
            name: 'TRON',
            amount: '100',
            address: 'T1',
          ),
        ],
        prices: {'BTCB': Decimal.parse('65000'), 'TRX': Decimal.parse('0.12')},
      );

      expect(total?.toStringAsFixed(2), '662.00');
    });

    test('calculates Ethereum chain assets with stable and wrapped prices', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'ETH',
            name: 'Ethereum',
            amount: '1.5',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'DAI',
            name: 'Dai Stablecoin',
            amount: '20',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'WBTC',
            name: 'Wrapped BTC',
            amount: '0.01',
            address: '0x1',
          ),
        ],
        prices: {'ETH': Decimal.parse('3000'), 'WBTC': Decimal.parse('65000')},
      );

      expect(total?.toStringAsFixed(2), '5170.00');
    });

    test('formats non-stable asset value as stable coin equivalent', () {
      final bnbText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'BNB',
          name: 'BNB',
          amount: '2',
          address: '0x1',
        ),
        prices: {'BNB': Decimal.parse('300')},
      );
      final usdtText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '100',
          address: '0x1',
        ),
      );

      expect(bnbText, '≈ 600.00 USDT');
      expect(usdtText, isNull);
    });

    test('formats zero and tiny non-stable asset values for UI display', () {
      final zeroText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'BNB',
          name: 'BNB',
          amount: '0',
          address: '0x1',
        ),
        prices: {'BNB': Decimal.parse('600')},
      );
      final tinyText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.ethereum,
          symbol: 'ETH',
          name: 'Ethereum',
          amount: '0.000001',
          address: '0x1',
        ),
        prices: {'ETH': Decimal.parse('1671.12')},
      );

      expect(zeroText, '≈ 0.00 USDT');
      expect(tinyText, '≈ 0.001671 USDT');
    });

    test('parses Binance prices for requested non-stable assets', () {
      final prices = service.parseBinancePrices(
        [
          {'symbol': 'BNBUSDT', 'price': '300.50'},
          {'symbol': 'TRXUSDT', 'price': '0.1201'},
          {'symbol': 'BTCUSDT', 'price': '65000'},
          {'symbol': 'OKBUSDT', 'price': '52.25'},
          {'symbol': 'SOLUSDT', 'price': '150.75'},
          {'symbol': 'ARBUSDT', 'price': '1.23'},
        ],
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toStringAsFixed(2), '300.50');
      expect(prices['TRX']?.toString(), '0.1201');
      expect(prices['BTCB']?.toString(), '65000');
      expect(prices['WBTC']?.toString(), '65000');
      expect(prices['OKB']?.toString(), '52.25');
      expect(prices['SOL']?.toString(), '150.75');
      expect(prices['ARB']?.toString(), '1.23');
    });

    test('parses single Binance ticker response', () {
      final prices = service.parseBinancePrices(
        {'symbol': 'BNBUSDT', 'price': '300.50'},
        ['BNB'],
      );

      expect(prices['BNB']?.toStringAsFixed(2), '300.50');
    });

    test('parses OKX USDT prices for requested non-stable assets', () {
      final prices = service.parseOkxPrices(
        {
          'code': '0',
          'data': [
            {'instId': 'BNB-USDT', 'last': '302.1'},
            {'instId': 'TRX-USDT', 'last': '0.1208'},
            {'instId': 'BTC-USDT', 'last': '65100'},
            {'instId': 'OKB-USDT', 'last': '52.4'},
            {'instId': 'SOL-USDT', 'last': '151.2'},
            {'instId': 'ARB-USDT', 'last': '1.24'},
          ],
        },
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '302.1');
      expect(prices['TRX']?.toString(), '0.1208');
      expect(prices['BTCB']?.toString(), '65100');
      expect(prices['WBTC']?.toString(), '65100');
      expect(prices['OKB']?.toString(), '52.4');
      expect(prices['SOL']?.toString(), '151.2');
      expect(prices['ARB']?.toString(), '1.24');
    });

    test('parses requested prices from OKX full spot ticker response', () {
      final prices = service.parseOkxPrices(
        {
          'code': '0',
          'data': [
            {'instId': 'DOGE-USDT', 'last': '0.11'},
            {'instId': 'BNB-USDT', 'last': '575.3'},
            {'instId': 'BTC-USDT', 'last': '60920.7'},
            {'instId': 'OKB-USDT', 'last': '68.62'},
          ],
        },
        ['BNB', 'BTCB', 'OKB'],
      );

      expect(prices['BNB']?.toString(), '575.3');
      expect(prices['BTCB']?.toString(), '60920.7');
      expect(prices['OKB']?.toString(), '68.62');
      expect(prices.containsKey('DOGE'), isFalse);
    });

    test('parses CoinGecko fallback prices by wallet symbol', () {
      final prices = service.parseCoinGeckoPrices(
        {
          'binancecoin': {'usd': 301.25},
          'tron': {'usd': 0.119},
          'ethereum': {'usd': '3500.5'},
          'bitcoin': {'usd': 64999.99},
          'okb': {'usd': 52.3},
          'solana': {'usd': 150.8},
          'arbitrum': {'usd': 1.25},
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '301.25');
      expect(prices['TRX']?.toString(), '0.119');
      expect(prices['ETH']?.toString(), '3500.5');
      expect(prices['BTCB']?.toString(), '64999.99');
      expect(prices['WBTC']?.toString(), '64999.99');
      expect(prices['OKB']?.toString(), '52.3');
      expect(prices['SOL']?.toString(), '150.8');
      expect(prices['ARB']?.toString(), '1.25');
    });

    test('parses DeFiLlama prices by CoinGecko ids', () {
      final prices = service.parseDefiLlamaPrices(
        {
          'coins': {
            'coingecko:binancecoin': {'price': 600.21},
            'coingecko:bitcoin': {'price': '62722.09'},
            'coingecko:ethereum': {'price': 1671.12},
            'coingecko:solana': {'price': 66.16},
            'coingecko:arbitrum': {'price': 1.26},
          },
        },
        ['BNB', 'BTCB', 'WBTC', 'ETH', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '600.21');
      expect(prices['BTCB']?.toString(), '62722.09');
      expect(prices['WBTC']?.toString(), '62722.09');
      expect(prices['ETH']?.toString(), '1671.12');
      expect(prices['SOL']?.toString(), '66.16');
      expect(prices['ARB']?.toString(), '1.26');
    });

    test('parses CoinPaprika fallback prices by wallet symbol', () {
      final prices = service.parseCoinPaprikaPrices(
        [
          {
            'id': 'bnb-binance-coin',
            'quotes': {
              'USD': {'price': 599.93},
            },
          },
          {
            'id': 'btc-bitcoin',
            'quotes': {
              'USD': {'price': '62643.07'},
            },
          },
          {
            'id': 'sol-solana',
            'quotes': {
              'USD': {'price': 66.14},
            },
          },
          {
            'id': 'arb-arbitrum',
            'quotes': {
              'USD': {'price': 1.27},
            },
          },
        ],
        ['BNB', 'BTCB', 'WBTC', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '599.93');
      expect(prices['BTCB']?.toString(), '62643.07');
      expect(prices['WBTC']?.toString(), '62643.07');
      expect(prices['SOL']?.toString(), '66.14');
      expect(prices['ARB']?.toString(), '1.27');
    });

    test('parses CryptoCompare fallback prices by wallet symbol', () {
      final prices = service.parseCryptoComparePrices(
        {
          'BNB': {'USD': 574.65},
          'TRX': {'USD': 0.3202},
          'ETH': {'USD': 1566.43},
          'BTC': {'USD': 60913.71},
          'OKB': {'USD': 69.12},
          'SOL': {'USD': 151.4},
          'ARB': {'USD': 1.28},
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '574.65');
      expect(prices['TRX']?.toString(), '0.3202');
      expect(prices['ETH']?.toString(), '1566.43');
      expect(prices['BTCB']?.toString(), '60913.71');
      expect(prices['WBTC']?.toString(), '60913.71');
      expect(prices['OKB']?.toString(), '69.12');
      expect(prices['SOL']?.toString(), '151.4');
      expect(prices['ARB']?.toString(), '1.28');
    });

    test('uses stable coin prices without external price data', () {
      final total = service.calculateTotalUsdValue(const [
        ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '0',
          address: '0x1',
        ),
      ]);

      expect(service.formatUsdValue(total), r'$0.00');
    });

    test('returns null when no asset has a known USD price', () {
      final total = service.calculateTotalUsdValue(const [
        ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'UNKNOWN',
          name: 'Unknown Token',
          amount: '100',
          address: '0x1',
        ),
      ]);

      expect(total, isNull);
      expect(service.formatUsdValue(total), '--');
    });
  });
}
