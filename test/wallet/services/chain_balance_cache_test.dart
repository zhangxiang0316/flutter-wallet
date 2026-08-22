import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/chain_balance_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 22, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rebinds a builtin balance to the current RPC override', () async {
    final cache = ChainBalanceCache(now: () => now);
    const balance = ChainBalance(
      chain: WalletChain.ethereum,
      symbol: 'ETH',
      name: 'Ethereum',
      amount: '1.25',
      address: '0x1111111111111111111111111111111111111111',
      decimals: 18,
    );
    await cache.save('wallet-1', _snapshot(now, [balance]));
    final currentEthereum = WalletChain.ethereum.config.copyWith(
      rpcUrls: const ['https://user-ethereum-rpc.example'],
    );

    final loaded = await cache.load('wallet-1', chains: [currentEthereum]);

    expect(loaded, isNotNull);
    expect(loaded!.balances.single.chainConfig, same(currentEthereum));
    expect(
      loaded.balances.single.chainRef.rpcUrl,
      'https://user-ethereum-rpc.example',
    );
    expect(loaded.source, BalanceSnapshotSource.cache);
  });

  test('rebinds a custom EVM balance without persisting its RPC', () async {
    final cache = ChainBalanceCache(now: () => now);
    final originalChain = WalletChainConfig.customEvm(
      id: 'evm-999',
      name: 'Original Network',
      symbol: 'OLD',
      rpcUrls: const ['https://old-rpc.example'],
      evmChainId: 999,
    );
    final currentChain = WalletChainConfig.customEvm(
      id: 'evm-999',
      name: 'Current Network',
      symbol: 'NEW',
      rpcUrls: const ['https://current-rpc.example'],
      evmChainId: 999,
    );
    final balance = ChainBalance.config(
      chainConfig: originalChain,
      symbol: 'USDC',
      name: 'USD Coin',
      amount: '12.5',
      address: '0x1111111111111111111111111111111111111111',
      contractAddress: '0x2222222222222222222222222222222222222222',
      canonicalTokenId: 'usdc',
      decimals: 6,
    );
    await cache.save('wallet-1', _snapshot(now, [balance]));

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('cached_balances_v3_wallet-1')!;
    expect(encoded, isNot(contains('old-rpc.example')));
    expect(encoded, isNot(contains('current-rpc.example')));
    expect(encoded, isNot(contains('chainName')));
    expect(encoded, isNot(contains('chainSymbol')));

    final loaded = await cache.load('wallet-1', chains: [currentChain]);
    expect(loaded, isNotNull);
    expect(loaded!.balances.single.chainConfig, same(currentChain));
    expect(loaded.balances.single.chainRef.name, 'Current Network');
    expect(
      loaded.balances.single.chainRef.rpcUrl,
      'https://current-rpc.example',
    );
  });

  test(
    'migrates a legacy dynamic Polygon balance through current registry',
    () async {
      final polygonOverride = WalletChain.polygon.config.copyWith(
        rpcUrls: const ['https://user-polygon-rpc.example'],
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_balances_v2_wallet-legacy',
        jsonEncode({
          'timestamp': now.toIso8601String(),
          'balances': [
            {
              'chainId': 'evm-137',
              'chainName': 'Polygon',
              'chainSymbol': 'MATIC',
              'evmChainId': 137,
              'symbol': 'USDC',
              'name': 'USD Coin',
              'amount': '8.5',
              'address': '0x1111111111111111111111111111111111111111',
              'contractAddress': '0x3c499c542cef5e3811e1192ce70d8cc03d5c3359',
              'canonicalTokenId': 'usdc',
              'decimals': 6,
            },
          ],
        }),
      );

      final loaded = await ChainBalanceCache(
        now: () => now,
      ).load('wallet-legacy', chains: [polygonOverride]);

      expect(loaded, isNotNull);
      expect(loaded!.balances.single.chainId, WalletChain.polygon.id);
      expect(
        loaded.balances.single.chainRef.rpcUrl,
        'https://user-polygon-rpc.example',
      );
      expect(loaded.balances.single.chainRef.symbol, 'POL');
    },
  );

  test('returns expired cache only when stale data is allowed', () async {
    final asOf = now.subtract(const Duration(hours: 2));
    final cache = ChainBalanceCache(now: () => now);
    const balance = ChainBalance(
      chain: WalletChain.ethereum,
      symbol: 'ETH',
      name: 'Ethereum',
      amount: '1.25',
      address: '0x1111111111111111111111111111111111111111',
      decimals: 18,
    );
    await cache.save('wallet-stale', _snapshot(asOf, [balance]));

    expect(
      await cache.load('wallet-stale', chains: [WalletChain.ethereum.config]),
      isNull,
    );
    final stale = await cache.load(
      'wallet-stale',
      chains: [WalletChain.ethereum.config],
      allowStale: true,
    );

    expect(stale, isNotNull);
    expect(stale!.isStale, isTrue);
    expect(stale.asOf, asOf);
    expect(stale.source, BalanceSnapshotSource.cache);
  });

  test('preserves refresh metadata while loading from cache', () async {
    final cache = ChainBalanceCache(now: () => now);
    const balance = ChainBalance(
      chain: WalletChain.ethereum,
      symbol: 'ETH',
      name: 'Ethereum',
      amount: '1.25',
      address: '0x1111111111111111111111111111111111111111',
      decimals: 18,
    );
    await cache.save(
      'wallet-partial',
      ChainBalanceSnapshot(
        balances: const [balance],
        asOf: now,
        source: BalanceSnapshotSource.mixed,
        refreshStatus: BalanceRefreshStatus.partialFailure,
        isStale: true,
        error: 'balance_refresh_partial',
      ),
    );

    final loaded = await cache.load(
      'wallet-partial',
      chains: [WalletChain.ethereum.config],
    );

    expect(loaded, isNotNull);
    expect(loaded!.source, BalanceSnapshotSource.cache);
    expect(loaded.refreshStatus, BalanceRefreshStatus.partialFailure);
    expect(loaded.error, 'balance_refresh_partial');
    expect(loaded.hasError, isTrue);
  });

  test('drops balances whose chain no longer exists in registry', () async {
    final removedChain = WalletChainConfig.customEvm(
      id: 'evm-999',
      name: 'Removed Network',
      symbol: 'OLD',
      rpcUrls: const ['https://removed-rpc.example'],
      evmChainId: 999,
    );
    final removedBalance = ChainBalance.config(
      chainConfig: removedChain,
      symbol: 'OLD',
      name: 'Removed Coin',
      amount: '10',
      address: '0x1111111111111111111111111111111111111111',
      decimals: 18,
    );
    final cache = ChainBalanceCache(now: () => now);
    await cache.save('wallet-removed', _snapshot(now, [removedBalance]));

    final loaded = await cache.load(
      'wallet-removed',
      chains: [WalletChain.ethereum.config],
      allowStale: true,
    );

    expect(loaded, isNull);
  });
}

ChainBalanceSnapshot _snapshot(DateTime asOf, List<ChainBalance> balances) {
  return ChainBalanceSnapshot(
    balances: balances,
    asOf: asOf,
    source: BalanceSnapshotSource.network,
    refreshStatus: BalanceRefreshStatus.success,
  );
}
