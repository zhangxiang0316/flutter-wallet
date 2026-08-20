import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/chain_balance_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'migrates legacy dynamic Polygon balance to the builtin chain',
    () async {
      final polygon = WalletChainConfig.customEvm(
        id: 'evm-137',
        name: 'Polygon',
        symbol: 'MATIC',
        rpcUrls: const ['https://polygon-rpc.example'],
        evmChainId: 137,
      );
      final cache = ChainBalanceCache();
      final balance = ChainBalance.config(
        chainConfig: polygon,
        symbol: 'USDC',
        name: 'USD Coin',
        amount: '12.5',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
        canonicalTokenId: 'usdc',
        decimals: 6,
      );

      await cache.save('wallet-1', [balance]);
      final loaded = await cache.load('wallet-1');

      expect(loaded, hasLength(1));
      expect(loaded!.single.chainId, WalletChain.polygon.id);
      expect(loaded.single.chainRef.name, 'Polygon');
      expect(loaded.single.chainRef.evmChainId, 137);
      expect(loaded.single.chainRef.symbol, 'POL');
      expect(loaded.single.canonicalTokenId, 'usdc');
      expect(loaded.single.amount, '12.5');
    },
  );
}
