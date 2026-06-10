import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/wallet_custom_asset_service.dart';
import 'package:omnicast/wallet/services/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_secret_store.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';
import 'package:omnicast/wallet/utils/asset_amount_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

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

    test('derives BSC, Solana, and TRON addresses from a private key', () {
      final keyPair = service.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );

      expect(keyPair.bscAddress, '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf');
      expect(keyPair.tronAddress, 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC');
      expect(
        WalletTransferService.normalizeSolanaAddress(keyPair.solanaAddress),
        keyPair.solanaAddress,
      );
    });

    test('generates and imports mnemonic wallets deterministically', () {
      final mnemonic = service.generateMnemonic();
      expect(mnemonic.split(' '), hasLength(12));

      final first = service.importMnemonic(mnemonic);
      final second = service.importMnemonic(mnemonic);

      expect(first.mnemonic, mnemonic);
      expect(first.privateKeyHex, second.privateKeyHex);
      expect(first.bscAddress, second.bscAddress);
      expect(first.tronAddress, second.tronAddress);
      expect(first.solanaAddress, second.solanaAddress);
      expect(
        WalletTransferService.normalizeSolanaAddress(first.solanaAddress),
        first.solanaAddress,
      );
    });

    test('derives Solana signing seed from mnemonic and private key', () {
      final mnemonic = service.generateMnemonic();
      final keyPair = service.importMnemonic(mnemonic);
      final mnemonicSeed = service.solanaPrivateKeyFromMnemonic(mnemonic);
      final privateKeySeed = service.solanaPrivateKeyFromPrivateKey(
        keyPair.privateKeyHex,
      );

      expect(mnemonicSeed, hasLength(32));
      expect(privateKeySeed, hasLength(32));
      expect(
        service.importPrivateKey(keyPair.privateKeyHex).solanaAddress,
        isNotEmpty,
      );
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

    test('rejects malformed mnemonics', () {
      expect(
        () => service.importMnemonic('alpha beta gamma'),
        throwsA(isA<Exception>()),
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

  group('WalletAssetRegistry', () {
    test('serializes custom assets and merges them by contract address', () {
      const customAsset = WalletAsset(
        chain: WalletChain.bsc,
        symbol: 'CAKE',
        name: 'PancakeSwap Token',
        decimals: 18,
        contractAddress: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
        isCustom: true,
      );

      final decoded = WalletAsset.fromJson(customAsset.toJson());
      final merged = WalletAssetRegistry.mergeCustomAssets(WalletChain.bsc, [
        decoded,
        const WalletAsset(
          chain: WalletChain.bsc,
          symbol: 'CAKE2',
          name: 'Duplicate',
          decimals: 18,
          contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
          isCustom: true,
        ),
      ]);

      expect(decoded.isCustom, isTrue);
      expect(decoded.symbol, 'CAKE');
      expect(
        merged.where(
          (asset) => asset.contractAddress == decoded.contractAddress,
        ),
        hasLength(1),
      );
    });
  });

  group('WalletCustomAssetService', () {
    test('builds manually added assets with normalized EVM addresses', () {
      final service = WalletCustomAssetService();
      final asset = service.buildManualAsset(
        chain: WalletChain.bsc,
        contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
        symbol: 'cake',
        name: 'PancakeSwap Token',
        decimals: 18,
      );

      expect(asset.symbol, 'CAKE');
      expect(
        asset.contractAddress,
        '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
      );
      expect(asset.isCustom, isTrue);
    });
  });

  group('WalletSecretStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('encrypts private keys and rejects invalid passwords', () async {
      const privateKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final store = WalletSecretStore();

      await store.savePrivateKey(
        walletId: 'wallet-1',
        password: 'secret123',
        privateKeyHex: privateKey,
      );
      await store.saveMnemonic(
        walletId: 'wallet-1',
        password: 'secret123',
        mnemonic: mnemonic,
      );

      expect(await store.hasPrivateKey('wallet-1'), isTrue);
      expect(await store.hasMnemonic('wallet-1'), isTrue);
      expect(
        await store.readPrivateKey(walletId: 'wallet-1', password: 'secret123'),
        privateKey,
      );
      expect(
        await store.readMnemonic(walletId: 'wallet-1', password: 'secret123'),
        mnemonic,
      );
      expect(
        () => store.readPrivateKey(walletId: 'wallet-1', password: 'wrong'),
        throwsA(isA<WalletSecretInvalidPasswordException>()),
      );

      final rawStorage = await const FlutterSecureStorage().readAll();
      expect(rawStorage.values.join(), isNot(contains(privateKey)));
      expect(rawStorage.values.join(), isNot(contains(mnemonic)));
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
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final bnb = balances.firstWhere(
        (balance) =>
            balance.chain == WalletChain.bsc && balance.symbol == 'BNB',
      );
      expect(bnb.amount, '1');
      expect(bnb.error, isNull);
      final sol = balances.firstWhere(
        (balance) =>
            balance.chain == WalletChain.solana && balance.symbol == 'SOL',
      );
      expect(sol.amount, '1');
      expect(sol.error, isNull);
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
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
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

    test('does not block all balances when Solana RPC hangs', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter(hangSolana: true);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final sol = balances.firstWhere(
        (balance) =>
            balance.chain == WalletChain.solana && balance.symbol == 'SOL',
      );
      expect(sol.amount, '0');
      expect(sol.error, contains('timed out'));
      expect(
        balances.any(
          (balance) =>
              balance.chain == WalletChain.bsc && balance.symbol == 'BNB',
        ),
        isTrue,
      );
    });

    test(
      'loads Solana stable token balances from associated token accounts',
      () async {
        const solanaAddress = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
        const usdtMint = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
        const usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        final usdtAta = await _solanaAssociatedTokenAddress(
          ownerAddress: solanaAddress,
          mintAddress: usdtMint,
        );
        final usdcAta = await _solanaAssociatedTokenAddress(
          ownerAddress: solanaAddress,
          mintAddress: usdcMint,
        );
        final dio = Dio();
        final adapter = _FallbackRpcAdapter(
          solanaTokenAccountBalances: {
            usdtAta: _solanaTokenBalance(amount: '1234567', decimals: 6),
            usdcAta: _solanaTokenBalance(amount: '2500000', decimals: 6),
          },
        );
        dio.httpClientAdapter = adapter;
        final service = ChainBalanceService(dio: dio);

        final balances = await service.loadBalances(
          bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
          tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
          solanaAddress: solanaAddress,
        );

        final usdt = balances.firstWhere(
          (balance) =>
              balance.chain == WalletChain.solana && balance.symbol == 'USDT',
        );
        final usdc = balances.firstWhere(
          (balance) =>
              balance.chain == WalletChain.solana && balance.symbol == 'USDC',
        );

        expect(usdt.amount, '1.234567');
        expect(usdc.amount, '2.5');
        expect(usdt.error, isNull);
        expect(usdc.error, isNull);
        expect(
          adapter.solanaMethods.where(
            (method) => method == 'getTokenAccountBalance',
          ),
          hasLength(2),
        );
      },
    );
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
        ],
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB', 'SOL'],
      );

      expect(prices['BNB']?.toStringAsFixed(2), '300.50');
      expect(prices['TRX']?.toString(), '0.1201');
      expect(prices['BTCB']?.toString(), '65000');
      expect(prices['WBTC']?.toString(), '65000');
      expect(prices['OKB']?.toString(), '52.25');
      expect(prices['SOL']?.toString(), '150.75');
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
          ],
        },
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB', 'SOL'],
      );

      expect(prices['BNB']?.toString(), '302.1');
      expect(prices['TRX']?.toString(), '0.1208');
      expect(prices['BTCB']?.toString(), '65100');
      expect(prices['WBTC']?.toString(), '65100');
      expect(prices['OKB']?.toString(), '52.4');
      expect(prices['SOL']?.toString(), '151.2');
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
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB', 'SOL'],
      );

      expect(prices['BNB']?.toString(), '301.25');
      expect(prices['TRX']?.toString(), '0.119');
      expect(prices['ETH']?.toString(), '3500.5');
      expect(prices['BTCB']?.toString(), '64999.99');
      expect(prices['WBTC']?.toString(), '64999.99');
      expect(prices['OKB']?.toString(), '52.3');
      expect(prices['SOL']?.toString(), '150.8');
    });

    test('parses DeFiLlama prices by CoinGecko ids', () {
      final prices = service.parseDefiLlamaPrices(
        {
          'coins': {
            'coingecko:binancecoin': {'price': 600.21},
            'coingecko:bitcoin': {'price': '62722.09'},
            'coingecko:ethereum': {'price': 1671.12},
            'coingecko:solana': {'price': 66.16},
          },
        },
        ['BNB', 'BTCB', 'WBTC', 'ETH', 'SOL'],
      );

      expect(prices['BNB']?.toString(), '600.21');
      expect(prices['BTCB']?.toString(), '62722.09');
      expect(prices['WBTC']?.toString(), '62722.09');
      expect(prices['ETH']?.toString(), '1671.12');
      expect(prices['SOL']?.toString(), '66.16');
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
        ],
        ['BNB', 'BTCB', 'WBTC', 'SOL'],
      );

      expect(prices['BNB']?.toString(), '599.93');
      expect(prices['BTCB']?.toString(), '62643.07');
      expect(prices['WBTC']?.toString(), '62643.07');
      expect(prices['SOL']?.toString(), '66.14');
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
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB', 'SOL'],
      );

      expect(prices['BNB']?.toString(), '574.65');
      expect(prices['TRX']?.toString(), '0.3202');
      expect(prices['ETH']?.toString(), '1566.43');
      expect(prices['BTCB']?.toString(), '60913.71');
      expect(prices['WBTC']?.toString(), '60913.71');
      expect(prices['OKB']?.toString(), '69.12');
      expect(prices['SOL']?.toString(), '151.4');
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
      expect(WalletChain.solana.evmChainId, isNull);
      expect(WalletChain.solana.symbol, 'SOL');
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

    test('submits native Solana transfer through RPC', () async {
      final adapter = _FallbackRpcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
          keyPair.privateKeyHex,
        ),
        asset: ChainBalance(
          chain: WalletChain.solana,
          symbol: 'SOL',
          name: 'Solana',
          amount: '1',
          address: keyPair.solanaAddress,
          decimals: 9,
        ),
        toAddress: '11111111111111111111111111111111',
        amount: '0.001',
      );

      expect(hash, 'solana-signature');
      expect(adapter.solanaMethods, contains('getLatestBlockhash'));
      expect(adapter.solanaMethods, contains('sendTransaction'));
      expect(adapter.lastSolanaTransactionBase64, isNotEmpty);
      expect(
        base64Decode(adapter.lastSolanaTransactionBase64!).length,
        greaterThan(100),
      );
    });

    test('submits SPL token transfer through RPC', () async {
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final sourceTokenAccount = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000002',
          )
          .solanaAddress;
      final recipient = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000003',
          )
          .solanaAddress;
      final adapter = _FallbackRpcAdapter(
        solanaTokenAccountPubkey: sourceTokenAccount,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);

      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
          keyPair.privateKeyHex,
        ),
        asset: ChainBalance(
          chain: WalletChain.solana,
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '10',
          address: keyPair.solanaAddress,
          contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          decimals: 6,
        ),
        toAddress: recipient,
        amount: '1.25',
      );

      expect(hash, 'solana-signature');
      expect(adapter.solanaMethods, contains('getTokenAccountsByOwner'));
      expect(adapter.solanaMethods, contains('getLatestBlockhash'));
      expect(adapter.solanaMethods, contains('sendTransaction'));
      expect(adapter.lastSolanaTransactionBase64, isNotEmpty);
      expect(
        base64Decode(adapter.lastSolanaTransactionBase64!).length,
        greaterThan(180),
      );
    });
  });
}

class _FallbackRpcAdapter implements HttpClientAdapter {
  _FallbackRpcAdapter({
    this.failTronGridAccount = false,
    this.hangSolana = false,
    this.solanaTokenAccountPubkey,
    this.solanaTokenAccountBalances = const {},
  });

  final bool failTronGridAccount;
  final bool hangSolana;
  final String? solanaTokenAccountPubkey;
  final Map<String, Map<String, dynamic>> solanaTokenAccountBalances;
  final calls = <String>[];
  final solanaMethods = <String>[];
  String? lastSolanaTransactionBase64;

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

    if (origin == 'https://api.mainnet-beta.solana.com') {
      if (hangSolana) {
        return Completer<ResponseBody>().future;
      }
      final method = _solanaMethod(options.data);
      if (method != null) {
        solanaMethods.add(method);
      }
      if (_isSolanaMethod(options.data, 'getBalance')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'value': 1000000000},
        });
      }
      if (_isSolanaMethod(options.data, 'getTokenAccountBalance')) {
        final account = _firstSolanaParam(options.data);
        final tokenBalance = solanaTokenAccountBalances[account];
        if (tokenBalance == null) {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32602, 'message': 'could not find account'},
          });
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'value': tokenBalance},
        });
      }
      if (_isSolanaMethod(options.data, 'getTokenAccountsByOwner')) {
        final pubkey = solanaTokenAccountPubkey;
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'value': pubkey == null
                ? []
                : [
                    {'pubkey': pubkey},
                  ],
          },
        });
      }
      if (_isSolanaMethod(options.data, 'getLatestBlockhash')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'context': {'slot': 1},
            'value': {
              'blockhash': '11111111111111111111111111111111',
              'lastValidBlockHeight': 1,
            },
          },
        });
      }
      if (_isSolanaMethod(options.data, 'sendTransaction')) {
        final params = options.data is Map ? options.data['params'] : null;
        if (params is List && params.isNotEmpty && params.first is String) {
          lastSolanaTransactionBase64 = params.first as String;
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': 'solana-signature',
        });
      }
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

  bool _isSolanaMethod(dynamic data, String method) {
    return data is Map && data['method'] == method;
  }

  String? _solanaMethod(dynamic data) {
    return data is Map ? data['method']?.toString() : null;
  }

  String? _firstSolanaParam(dynamic data) {
    final params = data is Map ? data['params'] : null;
    if (params is! List || params.isEmpty) {
      return null;
    }
    return params.first?.toString();
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

Future<String> _solanaAssociatedTokenAddress({
  required String ownerAddress,
  required String mintAddress,
}) async {
  final owner = Ed25519HDPublicKey.fromBase58(ownerAddress);
  final mint = Ed25519HDPublicKey.fromBase58(mintAddress);
  final ata = await findAssociatedTokenAddress(owner: owner, mint: mint);
  return ata.toBase58();
}

Map<String, dynamic> _solanaTokenBalance({
  required String amount,
  required int decimals,
}) {
  return {'amount': amount, 'decimals': decimals};
}
