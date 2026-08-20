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

    test('builds Bitcoin transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '1',
        address: 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu',
      );

      final uri = service.transactionUri(asset, 'bitcoinTxHash');

      expect(uri.toString(), equals('https://mempool.space/tx/bitcoinTxHash'));
    });

    test('builds Sui transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.sui,
        symbol: 'SUI',
        name: 'Sui',
        amount: '1',
        address:
            '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973',
      );

      final uri = service.transactionUri(asset, 'suiTxDigest');

      expect(
        uri.toString(),
        equals('https://suiscan.xyz/mainnet/tx/suiTxDigest'),
      );
    });

    test('builds Aptos transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.aptos,
        symbol: 'APT',
        name: 'Aptos',
        amount: '1',
        address:
            '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973',
      );

      final uri = service.transactionUri(asset, '0xaptostx');

      expect(
        uri.toString(),
        equals('https://explorer.aptoslabs.com/txn/0xaptostx?network=mainnet'),
      );
    });

    test('builds Base transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.base,
        symbol: 'ETH',
        name: 'Ethereum',
        amount: '1',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
      );

      final uri = service.transactionUri(asset, '0xbaseTx');

      expect(uri.toString(), equals('https://basescan.org/tx/0xbaseTx'));
    });

    test('builds Polygon transaction URL', () {
      const asset = ChainBalance(
        chain: WalletChain.polygon,
        symbol: 'POL',
        name: 'Polygon Ecosystem Token',
        amount: '1',
        address: '0x742d35cc6634c0532925a3b844bc9e7595f0beb5',
      );

      final uri = service.transactionUri(asset, '0xpolygonTx');

      expect(uri.toString(), equals('https://polygonscan.com/tx/0xpolygonTx'));
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
