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

  test(
    'migrates legacy dynamic Avalanche balance to the builtin chain',
    () async {
      final avalanche = WalletChainConfig.customEvm(
        id: 'evm-43114',
        name: 'Avalanche C-Chain',
        symbol: 'AVAX',
        rpcUrls: const ['https://api.avax.network/ext/bc/C/rpc'],
        evmChainId: 43114,
      );
      final cache = ChainBalanceCache();
      final balance = ChainBalance.config(
        chainConfig: avalanche,
        symbol: 'AVAX',
        name: 'Avalanche',
        amount: '3.25',
        address: '0x2222222222222222222222222222222222222222',
        canonicalTokenId: 'avax',
        decimals: 18,
      );

      await cache.save('wallet-1', [balance]);
      final loaded = await cache.load('wallet-1');

      expect(loaded, hasLength(1));
      expect(loaded!.single.chainId, WalletChain.avalanche.id);
      expect(loaded.single.chainRef.name, 'Avalanche C-Chain');
      expect(loaded.single.chainRef.evmChainId, 43114);
      expect(loaded.single.chainRef.symbol, 'AVAX');
      expect(loaded.single.canonicalTokenId, 'avax');
      expect(loaded.single.amount, '3.25');
    },
  );
}
