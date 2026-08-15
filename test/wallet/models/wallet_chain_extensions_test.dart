import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_chain_extensions.dart';

void main() {
  group('WalletChainTypeExtension', () {
    test('isTron identifies TRON chain', () {
      expect(WalletChain.tron.isTron, isTrue);
      expect(WalletChain.tron.isSolana, isFalse);
      expect(WalletChain.tron.isEvm, isFalse);
    });

    test('isSolana identifies Solana chain', () {
      expect(WalletChain.solana.isSolana, isTrue);
      expect(WalletChain.solana.isTron, isFalse);
      expect(WalletChain.solana.isEvm, isFalse);
    });

    test('isEvm identifies EVM chains', () {
      expect(WalletChain.bsc.isEvm, isTrue);
      expect(WalletChain.bsc.isTron, isFalse);
      expect(WalletChain.bsc.isSolana, isFalse);

      expect(WalletChain.ethereum.isEvm, isTrue);
      expect(WalletChain.arbitrum.isEvm, isTrue);
    });

    test('isBitcoin identifies Bitcoin without treating it as EVM', () {
      expect(WalletChain.bitcoin.isBitcoin, isTrue);
      expect(WalletChain.bitcoin.isEvm, isFalse);
      expect(WalletChain.bitcoin.isSolana, isFalse);
      expect(WalletChain.bitcoin.isTron, isFalse);

      const configuredBitcoin = WalletChainConfig(
        id: 'custom-bitcoin-provider',
        name: 'Bitcoin',
        symbol: 'BTC',
        rpcUrls: ['https://example.com/api'],
        type: WalletChainType.bitcoin,
      );
      expect(configuredBitcoin.isBitcoin, isTrue);
      expect(configuredBitcoin.isEvm, isFalse);
    });
  });
}
