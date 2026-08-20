import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/token_portfolio_service.dart';

void main() {
  group('TokenPortfolioService', () {
    late TokenPortfolioService service;

    setUp(() {
      service = TokenPortfolioService();
    });

    test('aggregates trusted USDT balances across chains', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '1.25',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            decimals: 6,
          ),
          ChainBalance(
            chain: WalletChain.tron,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '2.75',
            address: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
            contractAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
            decimals: 6,
          ),
        ],
        chains: [WalletChain.ethereum.config, WalletChain.tron.config],
      );

      expect(result, hasLength(1));
      expect(result.single.canonicalTokenId, 'usdt');
      expect(result.single.symbol, 'USDT');
      expect(result.single.totalAmount, Decimal.parse('4'));
      expect(result.single.totalUsdValue, Decimal.parse('4'));
      expect(result.single.positions, hasLength(2));
    });

    test('does not merge an untrusted same-symbol custom token', () {
      final customChain = WalletChainConfig.customEvm(
        id: 'custom-100',
        name: 'Custom Network',
        symbol: 'CUS',
        rpcUrls: const ['https://rpc.example.com'],
        evmChainId: 100,
      );
      final result = service.build(
        balances: [
          const ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '10',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            decimals: 6,
          ),
          ChainBalance.config(
            chainConfig: customChain,
            symbol: 'USDT',
            name: 'Untrusted USDT',
            amount: '999',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x2222222222222222222222222222222222222222',
            decimals: 18,
          ),
        ],
        chains: [WalletChain.ethereum.config, customChain],
      );

      expect(result, hasLength(2));
      expect(
        result
            .firstWhere((item) => item.canonicalTokenId == 'usdt')
            .totalAmount,
        Decimal.parse('10'),
      );
      final customItem = result.singleWhere(
        (item) => item.canonicalTokenId.startsWith('asset:evm:100:'),
      );
      expect(customItem.totalAmount, Decimal.parse('999'));
      expect(customItem.totalUsdValue, isNull);
    });

    test('merges trusted Sui and Polygon USDC into the USDC portfolio', () {
      final builtInUsdcBalances = WalletAssetRegistry.all
          .where((asset) => asset.symbol == 'USDC')
          .map(
            (asset) => ChainBalance(
              chain: asset.chain!,
              symbol: asset.symbol,
              name: asset.name,
              amount: '0',
              address: '0x1111111111111111111111111111111111111111',
              contractAddress: asset.contractAddress,
              decimals: asset.decimals,
            ),
          );

      final result = service.build(
        balances: [...builtInUsdcBalances],
        chains: [...WalletChain.values.map((chain) => chain.config)],
      );

      expect(result, hasLength(1));
      expect(result.single.canonicalTokenId, 'usdc');
      expect(result.single.positions, hasLength(builtInUsdcBalances.length));
      expect(
        result.single.positions.any(
          (position) => position.chain.id == WalletChain.sui.id,
        ),
        isTrue,
      );
      expect(
        result.single.positions.any(
          (position) => position.chain.id == WalletChain.aptos.id,
        ),
        isTrue,
      );
      expect(
        result.single.positions.any(
          (position) => position.chain.evmChainId == 137,
        ),
        isTrue,
      );
    });

    test(
      'supports a user-defined token group without a code registry entry',
      () {
        final polygon = WalletChainConfig.customEvm(
          id: 'evm-137',
          name: 'Polygon',
          symbol: 'MATIC',
          rpcUrls: const ['https://polygon-rpc.example'],
          evmChainId: 137,
        );
        final base = WalletChainConfig.customEvm(
          id: 'evm-8453',
          name: 'Base',
          symbol: 'ETH',
          rpcUrls: const ['https://base-rpc.example'],
          evmChainId: 8453,
        );

        final result = service.build(
          balances: [
            ChainBalance.config(
              chainConfig: polygon,
              symbol: 'DAI',
              name: 'Dai Stablecoin',
              amount: '2',
              address: '0x1111111111111111111111111111111111111111',
              contractAddress: '0x1111111111111111111111111111111111111112',
              canonicalTokenId: 'dai',
              decimals: 18,
            ),
            ChainBalance.config(
              chainConfig: base,
              symbol: 'DAI',
              name: 'Dai Stablecoin',
              amount: '3',
              address: '0x1111111111111111111111111111111111111111',
              contractAddress: '0x1111111111111111111111111111111111111113',
              canonicalTokenId: 'dai',
              decimals: 18,
            ),
          ],
          chains: [polygon, base],
          prices: {'DAI': Decimal.one},
        );

        expect(result, hasLength(1));
        expect(result.single.canonicalTokenId, 'dai');
        expect(result.single.totalAmount, Decimal.fromInt(5));
        expect(result.single.totalUsdValue, Decimal.fromInt(5));
        expect(result.single.positions, hasLength(2));
      },
    );

    test('groups native BTC, BTCB and WBTC into one BTC portfolio', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.bitcoin,
            symbol: 'BTC',
            name: 'Bitcoin',
            amount: '0.5',
            address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
            canonicalTokenId: 'btc',
            decimals: 8,
          ),
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BTCB',
            name: 'Binance-Peg BTCB',
            amount: '0.1',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
            decimals: 18,
          ),
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'WBTC',
            name: 'Wrapped BTC',
            amount: '0.2',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
            decimals: 8,
          ),
        ],
        chains: [
          WalletChain.bitcoin.config,
          WalletChain.bsc.config,
          WalletChain.ethereum.config,
        ],
        prices: {
          'BTC': Decimal.parse('60000'),
          'BTCB': Decimal.parse('60000'),
          'WBTC': Decimal.parse('60000'),
        },
      );

      expect(result, hasLength(1));
      expect(result.single.canonicalTokenId, 'btc');
      expect(result.single.symbol, 'BTC');
      expect(result.single.totalAmount, Decimal.parse('0.8'));
      expect(result.single.totalUsdValue, Decimal.parse('48000'));
      expect(result.single.positions, hasLength(3));
    });

    test('groups Base and Polygon wrapped assets with ETH and BTC', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'ETH',
            name: 'Ethereum',
            amount: '1',
            address: '0x1111111111111111111111111111111111111111',
            decimals: 18,
          ),
          ChainBalance(
            chain: WalletChain.base,
            symbol: 'WETH',
            name: 'Wrapped Ether',
            amount: '0.5',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x4200000000000000000000000000000000000006',
            canonicalTokenId: 'eth',
            decimals: 18,
          ),
          ChainBalance(
            chain: WalletChain.polygon,
            symbol: 'WETH',
            name: 'Wrapped Ether',
            amount: '0.25',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
            canonicalTokenId: 'eth',
            decimals: 18,
          ),
          ChainBalance(
            chain: WalletChain.bitcoin,
            symbol: 'BTC',
            name: 'Bitcoin',
            amount: '0.2',
            address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
            canonicalTokenId: 'btc',
            decimals: 8,
          ),
          ChainBalance(
            chain: WalletChain.base,
            symbol: 'cbBTC',
            name: 'Coinbase Wrapped BTC',
            amount: '0.1',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf',
            canonicalTokenId: 'btc',
            decimals: 8,
          ),
          ChainBalance(
            chain: WalletChain.polygon,
            symbol: 'WBTC',
            name: 'Wrapped BTC',
            amount: '0.05',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6',
            canonicalTokenId: 'btc',
            decimals: 8,
          ),
        ],
        chains: [
          WalletChain.ethereum.config,
          WalletChain.base.config,
          WalletChain.polygon.config,
          WalletChain.bitcoin.config,
        ],
        prices: {'ETH': Decimal.parse('2000'), 'BTC': Decimal.parse('60000')},
      );

      final eth = result.singleWhere((item) => item.canonicalTokenId == 'eth');
      final btc = result.singleWhere((item) => item.canonicalTokenId == 'btc');
      expect(eth.symbol, 'ETH');
      expect(eth.totalAmount, Decimal.parse('1.75'));
      expect(eth.totalUsdValue, Decimal.parse('3500'));
      expect(eth.positions, hasLength(3));
      expect(btc.symbol, 'BTC');
      expect(btc.totalAmount, Decimal.parse('0.35'));
      expect(btc.totalUsdValue, Decimal.parse('21000'));
      expect(btc.positions, hasLength(3));
    });

    test('values Polygon native POL on the home portfolio', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.polygon,
            symbol: 'POL',
            name: 'Polygon Ecosystem Token',
            amount: '10',
            address: '0x1111111111111111111111111111111111111111',
            canonicalTokenId: 'pol',
            decimals: 18,
          ),
        ],
        chains: [WalletChain.polygon.config],
        prices: {'POL': Decimal.parse('0.25')},
      );

      expect(result, hasLength(1));
      expect(result.single.canonicalTokenId, 'pol');
      expect(result.single.totalAmount, Decimal.parse('10'));
      expect(result.single.totalUsdValue, Decimal.parse('2.5'));
    });

    test('values Avalanche native AVAX on the home portfolio', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.avalanche,
            symbol: 'AVAX',
            name: 'Avalanche',
            amount: '10',
            address: '0x1111111111111111111111111111111111111111',
            canonicalTokenId: 'avax',
            decimals: 18,
          ),
        ],
        chains: [WalletChain.avalanche.config],
        prices: {'AVAX': Decimal.parse('35')},
      );

      expect(result, hasLength(1));
      expect(result.single.canonicalTokenId, 'avax');
      expect(result.single.totalAmount, Decimal.parse('10'));
      expect(result.single.totalUsdValue, Decimal.parse('350'));
    });

    test('values Avalanche DAI.e as canonical DAI', () {
      final asset = WalletAssetRegistry.avalancheAssets.singleWhere(
        (item) => item.symbol == 'DAI.e',
      );
      final result = service.build(
        balances: [
          ChainBalance(
            chain: asset.chain!,
            symbol: asset.symbol,
            name: asset.name,
            amount: '12.5',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: asset.contractAddress,
            canonicalTokenId: asset.canonicalTokenId,
            decimals: asset.decimals,
          ),
        ],
        chains: [WalletChain.avalanche.config],
      );

      expect(result, hasLength(1));
      expect(result.single.canonicalTokenId, 'dai');
      expect(result.single.symbol, 'DAI');
      expect(result.single.totalAmount, Decimal.parse('12.5'));
      expect(result.single.totalUsdValue, Decimal.parse('12.5'));
    });

    test('keeps error state separate from successful zero balances', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BNB',
            name: 'BNB',
            amount: '0',
            address: '0x1111111111111111111111111111111111111111',
          ),
          ChainBalance(
            chain: WalletChain.solana,
            symbol: 'SOL',
            name: 'Solana',
            amount: '0',
            address: '7EqQdEUHxbf7pKPQiJKKCJVJeVVhJZCfE6xBx7KfqhAd',
            error: 'timeout',
          ),
        ],
        chains: [WalletChain.bsc.config, WalletChain.solana.config],
      );

      expect(result.map((item) => item.symbol), ['BNB', 'SOL']);
      final sol = result.singleWhere((item) => item.symbol == 'SOL');
      expect(sol.hasPartialError, isTrue);
      expect(sol.totalUsdValue, isNull);
    });

    test('sorts priced portfolios by descending USD value', () {
      final result = service.build(
        balances: const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BNB',
            name: 'BNB',
            amount: '1',
            address: '0x1111111111111111111111111111111111111111',
          ),
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '500',
            address: '0x1111111111111111111111111111111111111111',
            contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
            decimals: 6,
          ),
        ],
        chains: [WalletChain.bsc.config, WalletChain.ethereum.config],
        prices: {'BNB': Decimal.parse('300')},
      );

      expect(result.map((item) => item.symbol), ['USDT', 'BNB']);
    });
  });
}
