import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/adapters/chain_adapter.dart';
import 'package:omnicast/wallet/adapters/chain_adapter_registry.dart';
import 'package:omnicast/wallet/adapters/default_chain_adapter_registry.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';

void main() {
  group('ChainAdapterRegistry', () {
    test('reuses the application default registry', () {
      expect(
        identical(
          createDefaultChainAdapterRegistry(),
          createDefaultChainAdapterRegistry(),
        ),
        isTrue,
      );
    });

    test('registers every supported chain type', () {
      final registry = createDefaultChainAdapterRegistry();

      expect(
        registry.adapters.map((adapter) => adapter.type).toSet(),
        WalletChainType.values.toSet(),
      );
      for (final chain in WalletChain.values) {
        expect(registry.require(chain).supports(chain), isTrue);
      }
    });

    test('routes custom EVM networks through the EVM adapter', () {
      final registry = createDefaultChainAdapterRegistry();
      final chain = WalletChainConfig.customEvm(
        id: 'custom-evm',
        name: 'Custom EVM',
        symbol: 'ETH',
        rpcUrls: const ['https://rpc.example.com'],
        evmChainId: 12345,
      );

      final adapter = registry.require(
        chain,
        capability: ChainCapability.customNetworks,
      );

      expect(adapter.type, WalletChainType.evm);
      expect(adapter.walletAddress(_addresses), _addresses.evm);
    });

    test('selects the wallet address owned by each adapter', () {
      final registry = createDefaultChainAdapterRegistry();
      final expected = <WalletChain, String>{
        WalletChain.ethereum: _addresses.evm,
        WalletChain.tron: _addresses.tron,
        WalletChain.solana: _addresses.solana,
        WalletChain.bitcoin: _addresses.bitcoin,
        WalletChain.sui: _addresses.sui,
        WalletChain.aptos: _addresses.aptos,
      };

      for (final entry in expected.entries) {
        expect(
          registry.require(entry.key).walletAddress(_addresses),
          entry.value,
        );
      }
    });

    test('all adapters satisfy the common contract', () {
      final registry = createDefaultChainAdapterRegistry();
      for (final chain in WalletChain.values) {
        final adapter = registry.require(chain);
        final address = adapter.walletAddress(_addresses);
        expect(address, isNotEmpty);
        expect(adapter.normalizeAddress(address), isNotEmpty);
        expect(adapter.presentation(chain).label, isNotEmpty);
        expect(adapter.presentation(chain).addressHint, isNotEmpty);
        expect(adapter.addressExplorerUri(chain, address), isA<Uri>());
        expect(adapter.transactionExplorerUri(chain, 'tx-hash'), isA<Uri>());
        expect(
          adapter.capabilities.supports(
            ChainCapability.walletAddressResolution,
          ),
          isTrue,
        );
        expect(
          adapter.capabilities.supports(ChainCapability.blockExplorer),
          isTrue,
        );
        expect(
          adapter.balanceFallbackStrategy,
          chain == WalletChain.solana
              ? ChainBalanceFallbackStrategy.solanaOwnerTokenLookup
              : ChainBalanceFallbackStrategy.genericAssets,
        );
      }
    });

    test('rejects duplicate registration unless replace is explicit', () {
      final registry = ChainAdapterRegistry([_testAdapter]);

      expect(() => registry.register(_testAdapter), throwsStateError);
      expect(
        () => registry.register(_testAdapter, replace: true),
        returnsNormally,
      );
    });

    test('enforces declared capabilities', () {
      final registry = ChainAdapterRegistry([_testAdapter]);

      expect(
        () => registry.require(
          WalletChain.ethereum,
          capability: ChainCapability.transfer,
        ),
        throwsStateError,
      );
    });

    test('declares custom asset and payment URI capabilities explicitly', () {
      final registry = createDefaultChainAdapterRegistry();

      for (final chain in [
        WalletChain.ethereum,
        WalletChain.tron,
        WalletChain.solana,
      ]) {
        expect(
          registry
              .require(chain)
              .capabilities
              .supports(ChainCapability.customAssets),
          isTrue,
        );
      }
      for (final chain in [
        WalletChain.bitcoin,
        WalletChain.sui,
        WalletChain.aptos,
      ]) {
        expect(
          registry
              .require(chain)
              .capabilities
              .supports(ChainCapability.customAssets),
          isFalse,
        );
      }
      expect(registry.findByPaymentUriScheme('bitcoin')?.id, 'bitcoin');
      expect(registry.findByPaymentUriScheme('unknown'), isNull);
    });
  });
}

const _addresses = ChainWalletAddresses({
  WalletAddressNamespace.evm: '0x1111111111111111111111111111111111111111',
  WalletAddressNamespace.tron: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
  WalletAddressNamespace.solana: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
  WalletAddressNamespace.bitcoin: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
  WalletAddressNamespace.sui:
      '0x0000000000000000000000000000000000000000000000000000000000000001',
  WalletAddressNamespace.aptos: '0x1',
});

final _testAdapter = RegisteredChainAdapter(
  type: WalletChainType.evm,
  addressNamespace: WalletAddressNamespace.evm,
  capabilities: const ChainCapabilities({ChainCapability.addressValidation}),
  walletAddressSelector: (addresses) => addresses.evm,
  addressNormalizer: (input) => input.trim(),
  addressExplorerBuilder: (chain, value) => null,
  transactionExplorerBuilder: (chain, value) => null,
);
