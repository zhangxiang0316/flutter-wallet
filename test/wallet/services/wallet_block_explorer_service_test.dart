import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/transaction/wallet_block_explorer_service.dart';

void main() {
  group('WalletBlockExplorerService', () {
    const service = WalletBlockExplorerService();

    test('builds builtin EVM transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.ethereum,
        symbol: 'ETH',
        name: 'Ethereum',
        amount: '1',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
      );

      final uri = service.transactionUri(asset, '0xabc123');

      expect(uri.toString(), equals('https://etherscan.io/tx/0xabc123'));
    });

    test('builds Solana transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.solana,
        symbol: 'SOL',
        name: 'Solana',
        amount: '1',
        address: '7EqQdEUHxbf7pKPQiJKKCJVJeVVhJZCfE6xBx7KfqhAd',
      );

      final uri = service.transactionUri(asset, 'solTxHash');

      expect(uri.toString(), equals('https://solscan.io/tx/solTxHash'));
    });

    test('returns null for blank transaction hash', () {
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'BNB',
        name: 'BNB',
        amount: '1',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
      );

      expect(service.transactionUri(asset, ' '), isNull);
    });
  });
}
