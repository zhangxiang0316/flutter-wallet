import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/home/controller/home_controller.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';
import 'package:omnicast/wallet/services/chain_balance_cache.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/config/wallet_asset_visibility_service.dart';
import 'package:omnicast/wallet/services/config/wallet_chain_config_service.dart';

void main() {
  final cachedAt = DateTime.utc(2026, 8, 22, 10);

  test(
    'partial refresh keeps the last successful balance and marks it stale',
    () async {
      final cache = _FakeBalanceCache(
        ChainBalanceSnapshot(
          balances: const [
            ChainBalance(
              chain: WalletChain.ethereum,
              symbol: 'ETH',
              name: 'Ethereum',
              amount: '2',
              address: _evmAddress,
              decimals: 18,
            ),
          ],
          asOf: cachedAt,
          source: BalanceSnapshotSource.network,
          refreshStatus: BalanceRefreshStatus.success,
        ),
      );
      final controller = _controller(
        cache: cache,
        networkBalances: const [
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'ETH',
            name: 'Ethereum',
            amount: '0',
            address: _evmAddress,
            decimals: 18,
            error: 'rpc unavailable',
          ),
          ChainBalance(
            chain: WalletChain.base,
            symbol: 'ETH',
            name: 'Ethereum',
            amount: '0.5',
            address: _evmAddress,
            decimals: 18,
          ),
        ],
      );

      await controller.refreshBalances();

      expect(controller.balanceSnapshotSource, BalanceSnapshotSource.mixed);
      expect(
        controller.balanceRefreshStatus,
        BalanceRefreshStatus.partialFailure,
      );
      expect(controller.isBalanceDataStale, isTrue);
      expect(controller.balanceAsOf, cachedAt);
      expect(
        controller.balances
            .singleWhere(
              (balance) => balance.chainId == WalletChain.ethereum.id,
            )
            .amount,
        '2',
      );
      expect(cache.savedSnapshot, isNotNull);
      expect(cache.savedSnapshot!.source, BalanceSnapshotSource.mixed);
      expect(cache.savedSnapshot!.isStale, isTrue);
    },
  );

  test(
    'successful refresh replaces cache metadata with a network snapshot',
    () async {
      final cache = _FakeBalanceCache(null);
      final controller = _controller(
        cache: cache,
        networkBalances: const [
          ChainBalance(
            chain: WalletChain.base,
            symbol: 'ETH',
            name: 'Ethereum',
            amount: '1.5',
            address: _evmAddress,
            decimals: 18,
          ),
        ],
      );

      await controller.refreshBalances();

      expect(controller.balanceSnapshotSource, BalanceSnapshotSource.network);
      expect(controller.balanceRefreshStatus, BalanceRefreshStatus.success);
      expect(controller.isBalanceDataStale, isFalse);
      expect(controller.balanceRefreshError, isNull);
      expect(controller.balanceAsOf, isNotNull);
      expect(cache.savedSnapshot, isNotNull);
      expect(cache.savedSnapshot!.refreshStatus, BalanceRefreshStatus.success);
      expect(cache.savedSnapshot!.balances.single.amount, '1.5');
    },
  );
}

const _evmAddress = '0x1111111111111111111111111111111111111111';

HomeController _controller({
  required _FakeBalanceCache cache,
  required List<ChainBalance> networkBalances,
}) {
  final chains = [WalletChain.ethereum.config, WalletChain.base.config];
  return HomeController(
      balanceCache: cache,
      balanceService: _FakeBalanceService(networkBalances),
      valuationService: _FakeValuationService(),
      assetVisibilityService: _FakeAssetVisibilityService(),
      chainConfigService: _FakeChainConfigService(chains),
    )
    ..wallet = WalletAccount(
      id: 'wallet-1',
      name: 'Wallet 1',
      bscAddress: _evmAddress,
      tronAddress: '',
      createdAt: DateTime.utc(2026, 8, 22),
    );
}

class _FakeBalanceService extends ChainBalanceService {
  _FakeBalanceService(this.result);

  final List<ChainBalance> result;

  @override
  Future<List<ChainBalance>> loadBalances({
    required String bscAddress,
    required String tronAddress,
    required String solanaAddress,
    String suiAddress = '',
    String aptosAddress = '',
    String bitcoinAddress = '',
    ChainBalancesCallback? onChainBalances,
  }) async {
    return result;
  }
}

class _FakeBalanceCache extends ChainBalanceCache {
  _FakeBalanceCache(this.snapshot);

  final ChainBalanceSnapshot? snapshot;
  ChainBalanceSnapshot? savedSnapshot;

  @override
  Future<ChainBalanceSnapshot?> load(
    String walletId, {
    required List<WalletChainConfig> chains,
    bool allowStale = false,
  }) async {
    return snapshot;
  }

  @override
  Future<void> save(String walletId, ChainBalanceSnapshot snapshot) async {
    savedSnapshot = snapshot;
  }
}

class _FakeChainConfigService extends WalletChainConfigService {
  _FakeChainConfigService(this.chains);

  final List<WalletChainConfig> chains;

  @override
  Future<List<WalletChainConfig>> loadEnabledChains() async => chains;
}

class _FakeAssetVisibilityService extends WalletAssetVisibilityService {
  @override
  Future<Set<String>> loadHiddenAssetKeys() async => {};
}

class _FakeValuationService extends AssetValuationService {
  @override
  Map<String, Decimal> get cachedUsdPrices => const {};

  @override
  Future<Map<String, Decimal>> loadUsdPrices(
    List<ChainBalance> balances,
  ) async => const {};
}
