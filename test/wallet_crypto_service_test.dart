import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_secret_store.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';
import 'package:omnicast/wallet/utils/asset_amount_formatter.dart';

void main() {
  group('formatAssetAmount', () {
    test('limits token amounts to 8 decimal places for display', () {
      expect(formatAssetAmount('1'), '1');
      expect(formatAssetAmount('1.2'), '1.2');
      expect(formatAssetAmount('1.2300000000'), '1.23');
      expect(formatAssetAmount('0.123456789'), '0.12345678');
      expect(formatAssetAmount('123.000000001'), '123');
    });
  });

  group('WalletCryptoService', () {
    late WalletCryptoService service;

    setUp(() {
      service = WalletCryptoService();
    });

    test('derives BSC and TRON addresses from a private key', () {
      final keyPair = service.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );

      expect(keyPair.bscAddress, '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf');
      expect(keyPair.tronAddress, 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC');
    });

    test('rejects malformed private keys', () {
      expect(() => service.importPrivateKey('abc'), throwsFormatException);
      expect(
        () => service.importPrivateKey(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsFormatException,
      );
    });
  });

  group('WalletAccount', () {
    test('does not serialize private keys to plain storage', () {
      final wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet 1',
        bscAddress: '0x1',
        tronAddress: 'T1',
        createdAt: DateTime.utc(2026),
        privateKeyHex: 'legacy-private-key',
      );

      expect(wallet.needsSecretMigration, isTrue);
      expect(wallet.toJson().containsKey('privateKeyHex'), isFalse);
    });
  });

  group('WalletSecretStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('encrypts private keys and rejects invalid passwords', () async {
      const privateKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final store = WalletSecretStore();

      await store.savePrivateKey(
        walletId: 'wallet-1',
        password: 'secret123',
        privateKeyHex: privateKey,
      );

      expect(await store.hasPrivateKey('wallet-1'), isTrue);
      expect(
        await store.readPrivateKey(walletId: 'wallet-1', password: 'secret123'),
        privateKey,
      );
      expect(
        () => store.readPrivateKey(walletId: 'wallet-1', password: 'wrong'),
        throwsA(isA<WalletSecretInvalidPasswordException>()),
      );

      final rawStorage = await const FlutterSecureStorage().readAll();
      expect(rawStorage.values.join(), isNot(contains(privateKey)));
    });
  });

  group('ChainBalanceService', () {
    test('encodes ERC20 balanceOf calls', () {
      expect(
        ChainBalanceService.erc20BalanceOfData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        ),
        '0x70a082310000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf',
      );
    });

    test('falls back to the next EVM RPC when the primary fails', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
      );

      final bnb = balances.firstWhere(
        (balance) =>
            balance.chain == WalletChain.bsc && balance.symbol == 'BNB',
      );
      expect(bnb.amount, '1');
      expect(bnb.error, isNull);
      expect(adapter.calls, contains('https://bsc-dataseed.bnbchain.org'));
      expect(adapter.calls, contains('https://bsc-rpc.publicnode.com'));
    });

    test('falls back to the next TRON RPC when TronGrid fails', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter(failTronGridAccount: true);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
      );

      final trx = balances.firstWhere(
        (balance) =>
            balance.chain == WalletChain.tron && balance.symbol == 'TRX',
      );
      expect(trx.amount, '1');
      expect(trx.error, isNull);
      expect(adapter.calls, contains('https://api.trongrid.io'));
      expect(adapter.calls, contains('https://tron-rpc.publicnode.com'));
    });
  });

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

    test('parses Binance prices for requested non-stable assets', () {
      final prices = service.parseBinancePrices(
        [
          {'symbol': 'BNBUSDT', 'price': '300.50'},
          {'symbol': 'TRXUSDT', 'price': '0.1201'},
          {'symbol': 'BTCUSDT', 'price': '65000'},
          {'symbol': 'OKBUSDT', 'price': '52.25'},
        ],
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB'],
      );

      expect(prices['BNB']?.toStringAsFixed(2), '300.50');
      expect(prices['TRX']?.toString(), '0.1201');
      expect(prices['BTCB']?.toString(), '65000');
      expect(prices['WBTC']?.toString(), '65000');
      expect(prices['OKB']?.toString(), '52.25');
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
          ],
        },
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB'],
      );

      expect(prices['BNB']?.toString(), '302.1');
      expect(prices['TRX']?.toString(), '0.1208');
      expect(prices['BTCB']?.toString(), '65100');
      expect(prices['WBTC']?.toString(), '65100');
      expect(prices['OKB']?.toString(), '52.4');
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
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB'],
      );

      expect(prices['BNB']?.toString(), '301.25');
      expect(prices['TRX']?.toString(), '0.119');
      expect(prices['ETH']?.toString(), '3500.5');
      expect(prices['BTCB']?.toString(), '64999.99');
      expect(prices['WBTC']?.toString(), '64999.99');
      expect(prices['OKB']?.toString(), '52.3');
    });

    test('parses CryptoCompare fallback prices by wallet symbol', () {
      final prices = service.parseCryptoComparePrices(
        {
          'BNB': {'USD': 574.65},
          'TRX': {'USD': 0.3202},
          'ETH': {'USD': 1566.43},
          'BTC': {'USD': 60913.71},
          'OKB': {'USD': 69.12},
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB'],
      );

      expect(prices['BNB']?.toString(), '574.65');
      expect(prices['TRX']?.toString(), '0.3202');
      expect(prices['ETH']?.toString(), '1566.43');
      expect(prices['BTCB']?.toString(), '60913.71');
      expect(prices['WBTC']?.toString(), '60913.71');
      expect(prices['OKB']?.toString(), '69.12');
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

  group('WalletTransferService', () {
    test('converts decimal amounts to raw units', () {
      expect(
        WalletTransferService.amountToRawUnits('1.25', 18).toString(),
        '1250000000000000000',
      );
      expect(
        WalletTransferService.amountToRawUnits('0.000001', 6).toString(),
        '1',
      );
      expect(
        () => WalletTransferService.amountToRawUnits('0.0000001', 6),
        throwsFormatException,
      );
    });

    test('formats raw fee units for display', () {
      expect(
        WalletTransferService.rawUnitsToAmount(
          BigInt.from(21000) * BigInt.from(3000000000),
          18,
        ),
        '0.000063',
      );
      expect(
        WalletTransferService.rawUnitsToAmount(BigInt.from(30000000), 6),
        '30',
      );
    });

    test('encodes ERC20 transfer data', () {
      expect(
        WalletTransferService.erc20TransferData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
          BigInt.from(1000000),
        ),
        '0xa9059cbb0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('defines Ethereum and X Layer as EVM chains', () {
      expect(WalletChain.ethereum.evmChainId, 1);
      expect(WalletChain.ethereum.symbol, 'ETH');
      expect(WalletChain.xLayer.evmChainId, 196);
      expect(WalletChain.xLayer.symbol, 'OKB');
      expect(
        WalletTransferService.normalizeBscAddress(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        ),
        '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf',
      );
    });

    test('encodes TRC20 transfer parameters', () {
      expect(
        WalletTransferService.trc20TransferParameter(
          'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
          BigInt.from(1000000),
        ),
        '0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });
  });
}

class _FallbackRpcAdapter implements HttpClientAdapter {
  _FallbackRpcAdapter({this.failTronGridAccount = false});

  final bool failTronGridAccount;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final origin = '${options.uri.scheme}://${options.uri.host}';
    calls.add(origin);

    if (origin == 'https://bsc-dataseed.bnbchain.org') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32000, 'message': 'temporary upstream error'},
      });
    }

    if (origin == 'https://bsc-rpc.publicnode.com') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmNativeRequest(options.data)
            ? '0x0de0b6b3a7640000'
            : '0x0',
      });
    }

    if (origin == 'https://ethereum-rpc.publicnode.com' ||
        origin == 'https://rpc.xlayer.tech') {
      return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x0'});
    }

    if (origin == 'https://api.trongrid.io' &&
        options.uri.path == '/wallet/getaccount') {
      if (failTronGridAccount) {
        return _jsonResponse({
          'Error': 'temporary upstream error',
        }, statusCode: 500);
      }
      return _jsonResponse({'balance': 0});
    }

    if (origin == 'https://tron-rpc.publicnode.com' &&
        options.uri.path == '/wallet/getaccount') {
      return _jsonResponse({'balance': 1000000});
    }

    if (origin == 'https://api.trongrid.io' &&
        options.uri.path.startsWith('/v1/accounts/')) {
      return _jsonResponse({'data': []});
    }

    return _jsonResponse({}, statusCode: 404);
  }

  bool _isEvmNativeRequest(dynamic data) {
    return data is Map && data['method'] == 'eth_getBalance';
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
