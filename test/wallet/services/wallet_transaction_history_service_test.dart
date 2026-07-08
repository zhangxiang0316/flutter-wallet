import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_history_api_config.dart';
import 'package:omnicast/wallet/services/wallet_transaction_history_service.dart';
import '../test_support/fallback_rpc_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletTransactionHistoryService', () {
    test('loads BSC native transactions from Moralis', () async {
      final adapter = FallbackRpcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(moralisApiKey: 'moralis-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'BNB',
        name: 'BNB',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        decimals: 18,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(1));
      expect(result.records.single.txHash, '0xmoralisnative');
      expect(result.records.single.amount, '1.25');
      expect(result.records.single.status, WalletTransactionStatus.success);
      expect(result.hasMore, isFalse);
      expect(adapter.calls.first, 'https://deep-index.moralis.io');
    });

    test('paginates BSC token transactions from Moralis', () async {
      final adapter = FallbackRpcAdapter(moralisTokenFullPage: true);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(moralisApiKey: 'moralis-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x55d398326f99059fF775485246999027B3197955',
        decimals: 18,
      );

      final firstPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );
      final secondPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
        cursor: firstPage.nextCursor,
      );

      expect(firstPage.records, hasLength(10));
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor?.moralisCursor, 'moralis-next');
      expect(secondPage.records.single.txHash, '0xmoralis-token-next');
      expect(secondPage.records.single.amount, '3');
      expect(adapter.moralisCursors, ['', 'moralis-next']);
      expect(
        adapter.moralisContractFilters,
        everyElement(['0x55d398326f99059fF775485246999027B3197955']),
      );
    });

    test('loads Arbitrum native transactions from Moralis', () async {
      final adapter = FallbackRpcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(moralisApiKey: 'moralis-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.arbitrum,
        symbol: 'ETH',
        name: 'Ethereum',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        decimals: 18,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(1));
      expect(result.records.single.txHash, '0xmoralisnative');
      expect(result.records.single.amount, '1.25');
      expect(adapter.moralisChains.single, 'arbitrum');
    });

    test('paginates Arbitrum token transactions from Moralis', () async {
      final adapter = FallbackRpcAdapter(moralisTokenFullPage: true);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(moralisApiKey: 'moralis-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.arbitrum,
        symbol: 'USDC',
        name: 'USD Coin',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
        decimals: 6,
      );

      final firstPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );
      final secondPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
        cursor: firstPage.nextCursor,
      );

      expect(firstPage.records, hasLength(10));
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor?.moralisCursor, 'moralis-next');
      expect(secondPage.records.single.txHash, '0xmoralis-token-next');
      expect(adapter.moralisChains, ['arbitrum', 'arbitrum']);
      expect(
        adapter.moralisContractFilters,
        everyElement(['0xaf88d065e77c8cC2239327C5EDb3A432268e5831']),
      );
    });

    test(
      'falls back to Etherscan V2 when Moralis token page is empty',
      () async {
        final adapter = FallbackRpcAdapter(moralisEmptyTokenPage: true);
        final dio = Dio()..httpClientAdapter = adapter;
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(
            etherscanApiKey: 'etherscan-key',
            moralisApiKey: 'moralis-key',
          ),
        );
        const asset = ChainBalance(
          chain: WalletChain.arbitrum,
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
          decimals: 6,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, hasLength(1));
        expect(result.records.single.txHash, '0xetherscanv2');
        expect(result.records.single.contractAddress, asset.contractAddress);
        expect(adapter.moralisChains, ['arbitrum']);
        expect(adapter.etherscanV2ChainIds, ['42161']);
      },
    );

    test(
      'uses global Etherscan key for Arbiscan fallback when V2 fails',
      () async {
        final adapter = FallbackRpcAdapter(
          moralisEmptyTokenPage: true,
          failEtherscanV2: true,
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(
            etherscanApiKey: 'etherscan-key',
            moralisApiKey: 'moralis-key',
          ),
        );
        const asset = ChainBalance(
          chain: WalletChain.arbitrum,
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
          decimals: 6,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, hasLength(1));
        expect(result.records.single.txHash, '0xarbiscan');
        expect(result.records.single.amount, '50.505051');
        expect(adapter.etherscanV2ChainIds, ['42161']);
        expect(adapter.arbiscanApiKeys, ['etherscan-key']);
      },
    );

    test('loads EVM token transactions from explorer API', () async {
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(
          etherscanApiKey: '',
          moralisApiKey: '',
        ),
      );
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x55d398326f99059fF775485246999027B3197955',
        decimals: 18,
      );

      final records = await service.loadAssetRecords(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(records, hasLength(1));
      expect(records.single.txHash, '0xbeef');
      expect(records.single.amount, '2');
      expect(records.single.direction, WalletTransactionDirection.outgoing);
      expect(records.single.source, WalletTransactionSource.remote);
      expect(records.single.feeAmount, '0.000021');
    });

    test('loads BSC token transaction from receipt by hash', () async {
      final dio = Dio()
        ..httpClientAdapter = FallbackRpcAdapter(bscTokenReceiptLookup: true);
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(
          etherscanApiKey: '',
          moralisApiKey: '',
        ),
      );
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x55d398326f99059fF775485246999027B3197955',
        decimals: 18,
      );

      final record = await service.loadTransactionRecordByHash(
        walletId: 'wallet-1',
        asset: asset,
        txHash: '0xreceipt-token',
      );

      expect(record, isNotNull);
      expect(record!.txHash, '0xreceipt-token');
      expect(record.amount, '0.001');
      expect(record.direction, WalletTransactionDirection.outgoing);
      expect(record.status, WalletTransactionStatus.success);
      expect(record.source, WalletTransactionSource.remote);
      expect(record.feeAmount, '0.00000172');
      expect(record.blockNumber, 107012617);
      expect(record.timestamp?.millisecondsSinceEpoch, 1782714292000);
    });

    test(
      'returns empty BSC token history when public providers are unavailable',
      () async {
        final adapter = FallbackRpcAdapter(
          bscScanDeprecated: true,
          bscTokenLogsFail: true,
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(
            etherscanApiKey: '',
            moralisApiKey: '',
          ),
        );
        const asset = ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
          decimals: 18,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, isEmpty);
        expect(result.hasMore, isFalse);
        expect(result.emptyReason, TransactionHistoryFailureKind.noRecords);
      },
    );

    test('paginates BSC token transactions from explorer API', () async {
      final adapter = FallbackRpcAdapter(
        bscScanResultsByPage: {
          1: List.generate(
            100,
            (index) => bscTokenTxItem(
              hash: '0xbsc-page1-$index',
              timestamp: 1700000000 - index,
            ),
          ),
          2: [bscTokenTxItem(hash: '0xbsc-page2-old', timestamp: 1699990000)],
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(
          etherscanApiKey: '',
          moralisApiKey: '',
        ),
      );
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x55d398326f99059fF775485246999027B3197955',
        decimals: 18,
      );

      final firstPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );
      final secondPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
        cursor: firstPage.nextCursor,
      );

      expect(firstPage.records, hasLength(10));
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor?.evmPage, 2);
      expect(secondPage.records.single.txHash, '0xbsc-page2-old');
      expect(secondPage.hasMore, isFalse);
      expect(adapter.bscScanPages, [1, 2]);
      expect(adapter.bscScanOffsets, everyElement(100));
    });

    test(
      'skips Etherscan V2 for BSC history with unsupported free key',
      () async {
        final adapter = FallbackRpcAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(
            etherscanApiKey: 'test-key',
            moralisApiKey: '',
          ),
        );
        const asset = ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
          decimals: 18,
        );

        final records = await service.loadAssetRecords(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(records.single.txHash, '0xbeef');
        expect(adapter.calls, isNot(contains('https://api.etherscan.io')));
        expect(adapter.etherscanV2ChainIds, isEmpty);
      },
    );

    test(
      'returns empty BSC native history when explorer is unavailable',
      () async {
        final adapter = FallbackRpcAdapter(failBscScan: true);
        final dio = Dio()..httpClientAdapter = adapter;
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(
            etherscanApiKey: '',
            moralisApiKey: '',
          ),
        );
        const asset = ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'BNB',
          name: 'BNB',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          decimals: 18,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, isEmpty);
        expect(result.hasMore, isFalse);
        expect(result.emptyReason, TransactionHistoryFailureKind.noRecords);
      },
    );

    test('classifies Moralis invalid API key errors', () async {
      final adapter = FallbackRpcAdapter(failMoralisInvalidApiKey: true);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(moralisApiKey: 'bad-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.bsc,
        symbol: 'BNB',
        name: 'BNB',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        decimals: 18,
      );

      expect(
        () => service.loadAssetRecordPage(walletId: 'wallet-1', asset: asset),
        throwsA(
          isA<TransactionHistoryLoadException>().having(
            (error) => error.kind,
            'kind',
            TransactionHistoryFailureKind.apiKeyInvalid,
          ),
        ),
      );
    });

    test(
      'returns empty X Layer native history without an indexed provider',
      () async {
        final adapter = FallbackRpcAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(
            etherscanApiKey: '',
            moralisApiKey: '',
          ),
        );
        const asset = ChainBalance(
          chain: WalletChain.xLayer,
          symbol: 'OKB',
          name: 'OKB',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          decimals: 18,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, isEmpty);
        expect(result.hasMore, isFalse);
        expect(adapter.calls, isNot(contains('https://api.etherscan.io')));
      },
    );

    test('loads X Layer token transactions from paged RPC logs', () async {
      final adapter = FallbackRpcAdapter(xLayerTokenLogFullPage: true);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(
          etherscanApiKey: '',
          moralisApiKey: '',
        ),
      );
      const asset = ChainBalance(
        chain: WalletChain.xLayer,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0x74b7F16337b8972027F6196A17a631aC6dE26d22',
        decimals: 18,
      );

      final firstPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );
      final secondPage = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
        cursor: firstPage.nextCursor,
      );

      expect(firstPage.records, hasLength(10));
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.nextCursor?.evmLogBeforeBlock, 500000);
      expect(secondPage.records.single.txHash, '0xxlayerold');
      expect(secondPage.records.single.amount, '2');
      expect(adapter.xLayerLogRanges.first, (950001, 1000000));
      expect(adapter.xLayerLogRanges, contains((450001, 500000)));
    });

    test(
      'falls back to Blockscout v2 for builtin EVM native history',
      () async {
        final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(etherscanApiKey: ''),
        );
        final asset = ChainBalance.config(
          chainConfig: WalletChain.ethereum.config,
          symbol: 'ETH',
          name: 'Ethereum',
          amount: '10',
          address: '0x1111111111111111111111111111111111111111',
          decimals: 18,
        );

        final records = await service.loadAssetRecords(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(records, hasLength(1));
        expect(records.single.txHash, '0xblocknative');
        expect(records.single.amount, '0.1');
        expect(records.single.direction, WalletTransactionDirection.incoming);
        expect(records.single.status, WalletTransactionStatus.success);
        expect(records.single.feeAmount, '0.000021');
      },
    );

    test('loads EVM token transactions from Blockscout v2', () async {
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: ''),
      );
      final asset = ChainBalance.config(
        chainConfig: WalletChain.ethereum.config,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: '0x1111111111111111111111111111111111111111',
        contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
        decimals: 6,
      );

      final records = await service.loadAssetRecords(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(records, hasLength(1));
      expect(records.single.txHash, '0xblocktoken');
      expect(records.single.amount, '2.5');
      expect(records.single.direction, WalletTransactionDirection.outgoing);
      expect(records.single.contractAddress, asset.contractAddress);
    });

    test('loads TRON token transactions from TronGrid API', () async {
      final dio = Dio()..httpClientAdapter = FallbackRpcAdapter();
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: ''),
      );
      const asset = ChainBalance(
        chain: WalletChain.tron,
        symbol: 'USDT',
        name: 'Tether USD',
        amount: '10',
        address: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        contractAddress: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        decimals: 6,
      );

      final records = await service.loadAssetRecords(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(records, hasLength(1));
      expect(records.single.txHash, 'tronhash1');
      expect(records.single.amount, '2.5');
      expect(records.single.direction, WalletTransactionDirection.outgoing);
      expect(records.single.source, WalletTransactionSource.remote);
    });

    test('loads native Solana transactions from RPC', () async {
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final recipient = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000002',
          )
          .solanaAddress;
      final dio = Dio()
        ..httpClientAdapter = FallbackRpcAdapter(
          solanaHistoryOwner: keyPair.solanaAddress,
          solanaHistoryRecipient: recipient,
        );
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: ''),
      );
      final asset = ChainBalance(
        chain: WalletChain.solana,
        symbol: 'SOL',
        name: 'Solana',
        amount: '10',
        address: keyPair.solanaAddress,
        decimals: 9,
      );

      final records = await service.loadAssetRecords(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(records, hasLength(1));
      expect(records.single.txHash, 'solana-history-signature');
      expect(records.single.amount, '1.25');
      expect(records.single.feeAmount, '0.000005');
      expect(records.single.direction, WalletTransactionDirection.outgoing);
    });

    test('loads native Solana transactions from Helius', () async {
      const owner = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
      const recipient = 'BPFLoaderUpgradeab1e11111111111111111111111';
      final dio = Dio()
        ..httpClientAdapter = FallbackRpcAdapter(
          heliusOwner: owner,
          heliusRecipient: recipient,
        );
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.solana,
        symbol: 'SOL',
        name: 'Solana',
        amount: '10',
        address: owner,
        decimals: 9,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(1));
      expect(result.records.single.txHash, 'helius-sol-signature');
      expect(result.records.single.amount, '1.25');
      expect(result.records.single.feeAmount, '0.000005');
      expect(result.records.single.blockNumber, 123);
      expect(
        result.records.single.direction,
        WalletTransactionDirection.outgoing,
      );
      expect(result.hasMore, isFalse);
    });

    test('loads SPL token transactions from Helius with pagination', () async {
      const owner = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
      const sender = 'BPFLoaderUpgradeab1e11111111111111111111111';
      const mint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
      final adapter = FallbackRpcAdapter(
        heliusOwner: owner,
        heliusRecipient: sender,
        heliusMint: mint,
        heliusFullPage: true,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.solana,
        symbol: 'USDC',
        name: 'USD Coin',
        amount: '10',
        address: owner,
        contractAddress: mint,
        decimals: 6,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(10));
      expect(result.records.first.txHash, 'helius-token-signature-0');
      expect(result.records.first.amount, '2.5');
      expect(
        result.records.first.direction,
        WalletTransactionDirection.incoming,
      );
      expect(result.hasMore, isTrue);
      expect(result.nextCursor?.solanaBefore, 'helius-token-signature-9');
    });

    test(
      'loads native Solana balance changes from Helius account data',
      () async {
        const owner = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
        final dio = Dio()
          ..httpClientAdapter = FallbackRpcAdapter(
            heliusOwner: owner,
            heliusUseAccountData: true,
          );
        final service = WalletTransactionHistoryService(
          dio: dio,
          apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
        );
        const asset = ChainBalance(
          chain: WalletChain.solana,
          symbol: 'SOL',
          name: 'Solana',
          amount: '10',
          address: owner,
          decimals: 9,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, hasLength(1));
        expect(result.records.single.txHash, 'helius-sol-account-data');
        expect(result.records.single.amount, '0.25');
        expect(
          result.records.single.direction,
          WalletTransactionDirection.outgoing,
        );
      },
    );

    test('loads SPL token balance changes from Helius account data', () async {
      const owner = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
      const mint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
      final dio = Dio()
        ..httpClientAdapter = FallbackRpcAdapter(
          heliusOwner: owner,
          heliusMint: mint,
          heliusUseAccountData: true,
        );
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.solana,
        symbol: 'USDC',
        name: 'USD Coin',
        amount: '10',
        address: owner,
        contractAddress: mint,
        decimals: 6,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(1));
      expect(result.records.single.txHash, 'helius-token-account-data');
      expect(result.records.single.amount, '2.5');
      expect(
        result.records.single.direction,
        WalletTransactionDirection.incoming,
      );
    });

    test('classifies Solana history API rate limits', () async {
      final dio = Dio()
        ..httpClientAdapter = FallbackRpcAdapter(failHeliusRateLimit: true);
      final service = WalletTransactionHistoryService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
      );
      const asset = ChainBalance(
        chain: WalletChain.solana,
        symbol: 'SOL',
        name: 'Solana',
        amount: '10',
        address: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
        decimals: 9,
      );

      expect(
        () => service.loadAssetRecords(walletId: 'wallet-1', asset: asset),
        throwsA(
          isA<TransactionHistoryLoadException>().having(
            (error) => error.kind,
            'kind',
            TransactionHistoryFailureKind.rateLimited,
          ),
        ),
      );
    });
  });
}
