import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/home/controller/home_controller.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController asset filters', () {
    late HomeController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = HomeController();
      controller.chains = [
        WalletChain.ethereum.config,
        WalletChain.solana.config,
      ];
      controller.visibleBalances = const [
        ChainBalance(
          chain: WalletChain.ethereum,
          symbol: 'ETH',
          name: 'Ethereum',
          amount: '1.25',
          address: '0x1111111111111111111111111111111111111111',
        ),
        ChainBalance(
          chain: WalletChain.ethereum,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '0',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0x2222222222222222222222222222222222222222',
        ),
        ChainBalance(
          chain: WalletChain.solana,
          symbol: 'SOL',
          name: 'Solana',
          amount: '3',
          address: '7EqQdEUHxbf7pKPQiJKKCJVJeVVhJZCfE6xBx7KfqhAd',
        ),
      ];
    });

    test('hides zero balances', () {
      controller.setHideZeroBalances(true);

      expect(
        controller.displayBalances.map((balance) => balance.symbol),
        isNot(contains('USDT')),
      );
      expect(
        controller.tokenPortfolioItems.map((item) => item.symbol),
        isNot(contains('USDT')),
      );
    });

    test('removes zero token portfolios when zero balances are hidden', () {
      controller.visibleBalances = const [
        ChainBalance(
          chain: WalletChain.ethereum,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '0',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0x2222222222222222222222222222222222222222',
        ),
        ChainBalance(
          chain: WalletChain.solana,
          symbol: 'SOL',
          name: 'Solana',
          amount: '3',
          address: '7EqQdEUHxbf7pKPQiJKKCJVJeVVhJZCfE6xBx7KfqhAd',
        ),
      ];
      controller.setHideZeroBalances(true);

      expect(controller.tokenPortfolioItems.map((item) => item.symbol), [
        'SOL',
      ]);
    });
  });
}
