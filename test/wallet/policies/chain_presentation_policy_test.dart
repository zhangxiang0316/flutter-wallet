import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/adapters/chain_adapter.dart';
import 'package:omnicast/wallet/adapters/chain_adapter_registry.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/policies/chain_presentation_policy.dart';

void main() {
  group('ChainPresentationPolicy', () {
    test('reads presentation from the injected registry', () {
      final registry = ChainAdapterRegistry([_adapter]);
      final policy = ChainPresentationPolicy(registry);

      final presentation = policy.presentation(WalletChain.ethereum);

      expect(presentation.colorValue, 0xFF123456);
      expect(presentation.label, 'E');
      expect(presentation.addressHint, '0x...');
    });

    test('observes adapter replacements on the shared registry', () {
      final registry = ChainAdapterRegistry([_adapter]);
      final policy = ChainPresentationPolicy(registry);
      registry.register(_replacementAdapter, replace: true);

      expect(policy.presentation(WalletChain.ethereum).label, 'R');
    });

    test('exposes only view interaction policies', () {
      final policy = ChainPresentationPolicy(ChainAdapterRegistry([_adapter]));

      expect(
        policy.extractAddress(
          WalletChain.ethereum,
          'pay 0x1111111111111111111111111111111111111111 now',
        ),
        '0x1111111111111111111111111111111111111111',
      );
      expect(
        policy.isValidAddress(
          WalletChain.ethereum,
          '0x1111111111111111111111111111111111111111',
        ),
        isTrue,
      );
      expect(policy.isValidAddress(WalletChain.ethereum, 'invalid'), isFalse);
      expect(
        policy.transferPolicy(WalletChain.ethereum).requiresNetworkConfirmation,
        isTrue,
      );
    });
  });
}

final _adapter = RegisteredChainAdapter(
  type: WalletChainType.evm,
  addressNamespace: WalletAddressNamespace.evm,
  capabilities: const ChainCapabilities({ChainCapability.addressValidation}),
  presentationBuilder: (_) => const ChainPresentation(
    colorValue: 0xFF123456,
    label: 'E',
    addressHint: '0x...',
  ),
  transferPolicyBuilder: (_) => const ChainTransferPolicy(
    caseInsensitiveAddress: true,
    requiresNetworkConfirmation: true,
    isBurnAddress: _neverBurnAddress,
  ),
  walletAddressSelector: (addresses) => addresses.evm,
  addressNormalizer: _normalizeEvm,
  addressExtractor: _extractEvm,
  addressExplorerBuilder: (chain, value) => null,
  transactionExplorerBuilder: (chain, value) => null,
);

final _replacementAdapter = RegisteredChainAdapter(
  type: WalletChainType.evm,
  addressNamespace: WalletAddressNamespace.evm,
  capabilities: const ChainCapabilities({ChainCapability.addressValidation}),
  presentationBuilder: (_) => const ChainPresentation(
    colorValue: 0xFF654321,
    label: 'R',
    addressHint: 'replacement',
  ),
  walletAddressSelector: (addresses) => addresses.evm,
  addressNormalizer: _normalizeEvm,
  addressExtractor: _extractEvm,
  addressExplorerBuilder: (chain, value) => null,
  transactionExplorerBuilder: (chain, value) => null,
);

bool _neverBurnAddress(String input) => false;

String _normalizeEvm(String input) {
  final value = input.trim();
  if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(value)) {
    throw const FormatException('Invalid EVM address');
  }
  return value.toLowerCase();
}

String? _extractEvm(String input) {
  return RegExp(r'0x[a-fA-F0-9]{40}').firstMatch(input)?.group(0);
}
