import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/services/transaction/wallet_block_explorer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletBlockExplorerService', () {
    test('builds default explorer URL for built-in chains', () {
      const service = WalletBlockExplorerService();
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'BNB',
        name: 'BNB',
        amount: '1',
        address: '0x1111111111111111111111111111111111111111',
        decimals: 18,
      );

      expect(
        service.addressUri(asset).toString(),
        'https://bscscan.com/address/0x1111111111111111111111111111111111111111',
      );
    });

    test('builds Bitcoin address explorer URL', () {
      const service = WalletBlockExplorerService();
      const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
      const asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '1',
        address: address,
        decimals: 8,
      );

      expect(
        service.addressUri(asset).toString(),
        'https://mempool.space/address/$address',
      );
    });

    test('builds Avalanche address explorer URL', () {
      const service = WalletBlockExplorerService();
      const address = '0x1111111111111111111111111111111111111111';
      const asset = ChainBalance(
        chain: WalletChain.avalanche,
        symbol: 'AVAX',
        name: 'Avalanche',
        amount: '1',
        address: address,
        decimals: 18,
      );

      expect(
        service.addressUri(asset).toString(),
        'https://snowtrace.io/address/$address',
      );
    });

    test('builds Sui address explorer URL', () {
      const service = WalletBlockExplorerService();
      const address =
          '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';
      const asset = ChainBalance(
        chain: WalletChain.sui,
        symbol: 'SUI',
        name: 'Sui',
        amount: '1',
        address: address,
        decimals: 9,
      );

      expect(
        service.addressUri(asset).toString(),
        'https://suiscan.xyz/mainnet/account/$address',
      );
    });

    test('builds explorer URL from custom EVM scan API URL', () {
      const service = WalletBlockExplorerService();
      final chain = WalletChainConfig.customEvm(
        id: 'evm-137',
        name: 'Polygon',
        symbol: 'MATIC',
        rpcUrls: const ['https://polygon-rpc.com'],
        evmChainId: 137,
        explorerApiUrl: 'https://api.polygonscan.com/api',
      );
      final asset = ChainBalance.config(
        chainConfig: chain,
        symbol: 'MATIC',
        name: 'Polygon',
        amount: '1',
        address: '0x2222222222222222222222222222222222222222',
        decimals: 18,
      );

      expect(
        service.addressUri(asset).toString(),
        'https://polygonscan.com/address/0x2222222222222222222222222222222222222222',
      );
    });
  });
}
