import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/config/wallet_chain_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_support/fallback_rpc_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletChainConfigService', () {
    test('provides Polygon as a builtin EVM chain', () {
      final polygon = WalletChainConfigService().builtinChains().singleWhere(
        (chain) => chain.id == WalletChain.polygon.id,
      );

      expect(polygon.isBuiltin, isTrue);
      expect(polygon.evmChainId, 137);
      expect(polygon.symbol, 'POL');
      expect(polygon.rpcUrl, 'https://polygon.drpc.org');
      expect(polygon.explorerApiUrl, 'https://api.etherscan.io/v2/api');
    });

    test('provides Avalanche as a builtin EVM chain', () {
      final avalanche = WalletChainConfigService().builtinChains().singleWhere(
        (chain) => chain.id == WalletChain.avalanche.id,
      );

      expect(avalanche.isBuiltin, isTrue);
      expect(avalanche.evmChainId, 43114);
      expect(avalanche.symbol, 'AVAX');
      expect(avalanche.rpcUrl, 'https://api.avax.network/ext/bc/C/rpc');
      expect(avalanche.explorerApiUrl, 'https://api.snowtrace.io/api');
    });

    test('rejects adding Avalanche again as a custom chain', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      expect(
        () => service.addCustomEvmChain(
          name: 'Avalanche Duplicate',
          symbol: 'AVAX',
          evmChainId: 43114,
          rpcUrls: const ['https://api.avax.network/ext/bc/C/rpc'],
        ),
        throwsA(isA<WalletChainConfigDuplicateException>()),
      );
    });

    test('rejects adding Polygon again as a custom chain', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      expect(
        () => service.addCustomEvmChain(
          name: 'Polygon Duplicate',
          symbol: 'POL',
          evmChainId: 137,
          rpcUrls: const ['https://polygon-rpc.com'],
        ),
        throwsA(isA<WalletChainConfigDuplicateException>()),
      );
    });

    test('validates RPC chain ID before adding custom EVM chain', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      final chain = await service.addCustomEvmChain(
        name: 'Gnosis',
        symbol: 'xdai',
        evmChainId: 100,
        rpcUrls: const ['https://gnosis-rpc.com'],
      );

      expect(chain.id, 'evm-100');
      expect(chain.symbol, 'XDAI');
      expect(chain.rpcUrls, ['https://gnosis-rpc.com']);
      expect(await service.loadCustomChains(), hasLength(1));
    });

    test(
      'uses the next RPC when the first custom EVM RPC is unavailable',
      () async {
        SharedPreferences.setMockInitialValues({});
        final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
        final service = WalletChainConfigService(dio: dio);

        final chain = await service.addCustomEvmChain(
          name: 'Gnosis',
          symbol: 'xdai',
          evmChainId: 100,
          rpcUrls: const [
            'https://gnosis-rpc-disabled.example',
            'https://gnosis-rpc.publicnode.com',
          ],
        );

        expect(chain.id, 'evm-100');
        expect(chain.rpcUrls.first, 'https://gnosis-rpc.publicnode.com');
        expect(chain.rpcUrls, contains('https://gnosis-rpc-disabled.example'));
      },
    );

    test('updates custom EVM chain metadata and RPC list', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      final chain = await service.addCustomEvmChain(
        name: 'Gnosis',
        symbol: 'xdai',
        evmChainId: 100,
        rpcUrls: const ['https://gnosis-rpc.com'],
      );
      final updated = await service.updateCustomEvmChain(
        chainId: chain.id,
        name: 'Gnosis Chain',
        symbol: 'xdai',
        rpcUrls: const [
          'https://gnosis-rpc-disabled.example',
          'https://gnosis-rpc.publicnode.com',
        ],
      );

      expect(updated.id, chain.id);
      expect(updated.evmChainId, 100);
      expect(updated.name, 'Gnosis Chain');
      expect(updated.symbol, 'XDAI');
      expect(updated.rpcUrls.first, 'https://gnosis-rpc.publicnode.com');
      expect((await service.loadCustomChains()).single.name, 'Gnosis Chain');
    });

    test('updates built-in EVM chain metadata and RPC list', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      final updated = await service.updateBuiltinChain(
        chainId: WalletChain.bsc.id,
        name: 'BNB Custom',
        symbol: 'bnbx',
        rpcUrls: const ['https://bsc-rpc.publicnode.com'],
      );

      expect(updated.id, WalletChain.bsc.id);
      expect(updated.isBuiltin, isTrue);
      expect(updated.evmChainId, WalletChain.bsc.evmChainId);
      expect(updated.name, 'BNB Custom');
      expect(updated.symbol, 'BNBX');
      expect(updated.rpcUrls, ['https://bsc-rpc.publicnode.com']);

      final loaded = (await service.loadBuiltinChains()).firstWhere(
        (chain) => chain.id == WalletChain.bsc.id,
      );
      expect(loaded.isBuiltin, isTrue);
      expect(loaded.name, 'BNB Custom');
      expect(loaded.symbol, 'BNBX');
      expect(loaded.rpcUrls, ['https://bsc-rpc.publicnode.com']);
    });

    test('updates built-in Solana metadata and RPC list', () async {
      SharedPreferences.setMockInitialValues({});
      final service = WalletChainConfigService();

      final updated = await service.updateBuiltinChain(
        chainId: WalletChain.solana.id,
        name: 'Solana Main',
        symbol: 'sol',
        rpcUrls: const ['https://solana-rpc.publicnode.com'],
      );

      expect(updated.id, WalletChain.solana.id);
      expect(updated.isBuiltin, isTrue);
      expect(updated.type, WalletChainType.solana);
      expect(updated.name, 'Solana Main');
      expect(updated.symbol, 'SOL');
      expect(updated.rpcUrls, ['https://solana-rpc.publicnode.com']);

      final loaded = (await service.loadEnabledChains()).firstWhere(
        (chain) => chain.id == WalletChain.solana.id,
      );
      expect(loaded.isBuiltin, isTrue);
      expect(loaded.name, 'Solana Main');
      expect(loaded.rpcUrls, ['https://solana-rpc.publicnode.com']);
    });
  });
}
