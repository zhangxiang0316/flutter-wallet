import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/adapters/chain_adapter.dart';
import 'package:omnicast/wallet/adapters/chain_adapter_registry.dart';
import 'package:omnicast/wallet/adapters/default_chain_adapter_registry.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';

void main() {
  group('ChainAdapterRegistry', () {
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
  });
}

const _addresses = ChainWalletAddresses(
  evm: '0x1111111111111111111111111111111111111111',
  tron: 'tron-address',
  solana: 'solana-address',
  bitcoin: 'bitcoin-address',
  sui: 'sui-address',
  aptos: 'aptos-address',
);

final _testAdapter = RegisteredChainAdapter(
  type: WalletChainType.evm,
  capabilities: const ChainCapabilities({ChainCapability.addressValidation}),
  walletAddressSelector: (addresses) => addresses.evm,
  addressNormalizer: (input) => input.trim(),
  addressExplorerBuilder: (chain, value) => null,
  transactionExplorerBuilder: (chain, value) => null,
);
