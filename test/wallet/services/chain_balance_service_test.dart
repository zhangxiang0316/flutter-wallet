import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/wallet_history_api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_support/fallback_rpc_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChainBalanceService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

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
      final adapter = FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final bnb = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.bsc.id && balance.symbol == 'BNB',
      );
      expect(bnb.amount, '1');
      expect(bnb.error, isNull);
      final sol = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.solana.id && balance.symbol == 'SOL',
      );
      expect(sol.amount, '1');
      expect(sol.error, isNull);
      expect(adapter.calls, contains('https://bsc-dataseed.bnbchain.org'));
      expect(adapter.calls, contains('https://bsc-rpc.publicnode.com'));
      expect(adapter.evmBalanceBatchCount, greaterThan(0));
    });

    test('refreshes only the requested chain for transfer preflight', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadChainBalances(
        chain: WalletChain.bsc.config,
        address: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
      );

      expect(balances, isNotEmpty);
      expect(balances.every((balance) => balance.chainId == 'bsc'), isTrue);
      expect(balances.firstWhere((balance) => balance.isNative).amount, '1');
      expect(adapter.solanaMethods, isEmpty);
    });

    test('reports each chain as soon as its balance batch completes', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);
      final completedChainIds = <String>[];

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
        onChainBalances: (chainBalances) {
          if (chainBalances.isNotEmpty) {
            completedChainIds.add(chainBalances.first.chainId);
          }
        },
      );

      expect(completedChainIds, contains(WalletChain.bsc.id));
      expect(completedChainIds, contains(WalletChain.solana.id));
      expect(completedChainIds, contains(WalletChain.tron.id));
      expect(completedChainIds.toSet().length, 9);
      expect(balances, isNotEmpty);
    });

    test('loads native Bitcoin balance from Esplora API', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter(bitcoinBalanceSats: 123456789);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
        bitcoinAddress: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );

      final bitcoin = balances.singleWhere(
        (balance) => balance.chainId == WalletChain.bitcoin.id,
      );
      expect(bitcoin.symbol, 'BTC');
      expect(bitcoin.amount, '1.23456789');
      expect(bitcoin.canonicalTokenId, 'btc');
      expect(bitcoin.error, isNull);
      expect(adapter.calls, contains('https://mempool.space'));
    });

    test('falls back to the next TRON RPC when TronGrid fails', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter(failTronGridAccount: true);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final trx = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.tron.id && balance.symbol == 'TRX',
      );
      expect(trx.amount, '1');
      expect(trx.error, isNull);
      expect(adapter.calls, contains('https://api.trongrid.io'));
      expect(adapter.calls, contains('https://tron-rpc.publicnode.com'));
    });

    test('sends TronGrid API key when loading TRON balances', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(tronGridApiKey: 'tron-key'),
      );

      await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      expect(adapter.tronGridHeaders['TRON-PRO-API-KEY'], 'tron-key');
    });

    test('uses Helius RPC first when loading Solana balances', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
      );

      await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      expect(adapter.calls, contains('https://mainnet.helius-rpc.com'));
      expect(adapter.solanaRpcApiKeys, contains('helius-key'));
    });

    test('does not block all balances when Solana RPC hangs', () async {
      final dio = Dio();
      final adapter = FallbackRpcAdapter(hangSolana: true);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final sol = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.solana.id && balance.symbol == 'SOL',
      );
      expect(sol.amount, '0');
      expect(sol.error, contains('timed out'));
      expect(
        balances.any(
          (balance) =>
              balance.chainId == WalletChain.bsc.id && balance.symbol == 'BNB',
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
        final usdtAta = await solanaAssociatedTokenAddress(
          ownerAddress: solanaAddress,
          mintAddress: usdtMint,
        );
        final usdcAta = await solanaAssociatedTokenAddress(
          ownerAddress: solanaAddress,
          mintAddress: usdcMint,
        );
        final dio = Dio();
        final adapter = FallbackRpcAdapter(
          solanaTokenAccountBalances: {
            usdtAta: solanaTokenBalance(amount: '1234567', decimals: 6),
            usdcAta: solanaTokenBalance(amount: '2500000', decimals: 6),
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
              balance.chainId == WalletChain.solana.id &&
              balance.symbol == 'USDT',
        );
        final usdc = balances.firstWhere(
          (balance) =>
              balance.chainId == WalletChain.solana.id &&
              balance.symbol == 'USDC',
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
}
