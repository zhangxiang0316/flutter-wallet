import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

    test('loads Sui transfers without including gas in the amount', () async {
      final dio = Dio()..httpClientAdapter = _SuiGraphqlAdapter();
      final service = WalletTransactionHistoryService(dio: dio);
      const walletAddress =
          '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';
      const asset = ChainBalance(
        chain: WalletChain.sui,
        symbol: 'SUI',
        name: 'Sui',
        amount: '2',
        address: walletAddress,
        decimals: 9,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(1));
      expect(result.records.single.amount, '1');
      expect(result.records.single.feeAmount, '0.000005');
      expect(
        result.records.single.direction,
        WalletTransactionDirection.outgoing,
      );
    });

    test(
      'loads Aptos APT transfers and resolves fee and counterparty',
      () async {
        final dio = Dio()..httpClientAdapter = _AptosHistoryAdapter();
        final service = WalletTransactionHistoryService(dio: dio);
        const walletAddress =
            '0x1111111111111111111111111111111111111111111111111111111111111111';
        const asset = ChainBalance(
          chain: WalletChain.aptos,
          symbol: 'APT',
          name: 'Aptos',
          amount: '2',
          address: walletAddress,
          decimals: 8,
        );

        final result = await service.loadAssetRecordPage(
          walletId: 'wallet-1',
          asset: asset,
        );

        expect(result.records, hasLength(1));
        expect(result.records.single.txHash, '0xaptostx');
        expect(result.records.single.amount, '1');
        expect(result.records.single.feeAmount, '0.0001');
        expect(
          result.records.single.direction,
          WalletTransactionDirection.outgoing,
        );
        expect(
          result.records.single.toAddress,
          '0x2222222222222222222222222222222222222222222222222222222222222222',
        );
        expect(result.records.single.blockNumber, 1234);
        expect(result.records.single.timestamp, DateTime.utc(2026, 8, 15, 12));
        expect(result.hasMore, isFalse);
      },
    );

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
        expect(adapter.moralisChains, ['arbitrum', 'arbitrum']);
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

    test('loads native Bitcoin transactions from Esplora', () async {
      const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
      final adapter = FallbackRpcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(dio: dio);
      const asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '1.25',
        address: address,
        decimals: 8,
        canonicalTokenId: 'btc',
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );
      final byHash = await service.loadTransactionRecordByHash(
        walletId: 'wallet-1',
        asset: asset,
        txHash: 'bitcoin-by-hash',
      );

      expect(result.records, hasLength(1));
      expect(result.records.single.amount, '0.5');
      expect(result.records.single.feeAmount, '0.00001');
      expect(
        result.records.single.direction,
        WalletTransactionDirection.incoming,
      );
      expect(result.records.single.status, WalletTransactionStatus.success);
      expect(result.records.single.blockNumber, 850000);
      expect(result.hasMore, isFalse);
      expect(byHash?.txHash, 'bitcoin-by-hash');
    });

    test('parses outgoing, self and pending Bitcoin transactions', () async {
      const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
      const other = 'bc1qotheraddressfortesting00000000000000000';
      final adapter = FallbackRpcAdapter(
        bitcoinHistoryTransactions: [
          {
            'txid': 'bitcoin-outgoing',
            'fee': 1000,
            'vin': [
              {
                'prevout': {
                  'scriptpubkey_address': address,
                  'value': 100000000,
                },
              },
            ],
            'vout': [
              {'scriptpubkey_address': other, 'value': 40000000},
              {'scriptpubkey_address': address, 'value': 59999000},
            ],
            'status': {
              'confirmed': true,
              'block_height': 850001,
              'block_time': 1700000001,
            },
          },
          {
            'txid': 'bitcoin-self',
            'fee': 1000,
            'vin': [
              {
                'prevout': {
                  'scriptpubkey_address': address,
                  'value': 100000000,
                },
              },
            ],
            'vout': [
              {'scriptpubkey_address': address, 'value': 99999000},
            ],
            'status': {
              'confirmed': true,
              'block_height': 850002,
              'block_time': 1700000002,
            },
          },
          {
            'txid': 'bitcoin-pending',
            'fee': 500,
            'vin': [
              {
                'prevout': {'scriptpubkey_address': other, 'value': 25000500},
              },
            ],
            'vout': [
              {'scriptpubkey_address': address, 'value': 25000000},
            ],
            'status': {'confirmed': false},
          },
        ],
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(dio: dio);
      const asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '1',
        address: address,
        decimals: 8,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );
      final records = {
        for (final record in result.records) record.txHash: record,
      };

      expect(
        records['bitcoin-outgoing']?.direction,
        WalletTransactionDirection.outgoing,
      );
      expect(records['bitcoin-outgoing']?.amount, '0.4');
      expect(
        records['bitcoin-self']?.direction,
        WalletTransactionDirection.selfTransfer,
      );
      expect(records['bitcoin-self']?.amount, '0.99999');
      expect(
        records['bitcoin-pending']?.status,
        WalletTransactionStatus.pending,
      );
      expect(records['bitcoin-pending']?.amount, '0.25');
    });

    test('returns a Bitcoin Esplora pagination cursor', () async {
      const address = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
      final transactions = List.generate(
        25,
        (index) => bitcoinTxItem(
          txid: 'bitcoin-page-${index.toString().padLeft(2, '0')}',
          walletAddress: address,
        ),
      );
      final adapter = FallbackRpcAdapter(
        bitcoinHistoryTransactions: transactions,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final service = WalletTransactionHistoryService(dio: dio);
      const asset = ChainBalance(
        chain: WalletChain.bitcoin,
        symbol: 'BTC',
        name: 'Bitcoin',
        amount: '1',
        address: address,
        decimals: 8,
      );

      final result = await service.loadAssetRecordPage(
        walletId: 'wallet-1',
        asset: asset,
      );

      expect(result.records, hasLength(25));
      expect(result.hasMore, isTrue);
      expect(result.nextCursor?.bitcoinLastSeenTxId, 'bitcoin-page-24');
    });
  });
}

class _SuiGraphqlAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const walletAddress =
        '0x936accb491f0facaac668baaedcf4d0cfc6da1120b66f77fa6a43af718669973';
    const recipientAddress =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'transactions': {
            'pageInfo': {'hasNextPage': false, 'endCursor': null},
            'nodes': [
              {
                'digest': 'suiTxDigest',
                'effects': {
                  'timestamp': '2026-08-15T12:00:00.000Z',
                  'status': 'SUCCESS',
                  'balanceChanges': {
                    'nodes': [
                      {
                        'amount': '-1000005000',
                        'coinType': {'repr': '0x2::sui::SUI'},
                        'owner': {'address': walletAddress},
                      },
                      {
                        'amount': '1000000000',
                        'coinType': {'repr': '0x2::sui::SUI'},
                        'owner': {'address': recipientAddress},
                      },
                    ],
                  },
                },
              },
            ],
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AptosHistoryAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    const walletAddress =
        '0x1111111111111111111111111111111111111111111111111111111111111111';
    const recipientAddress =
        '0x2222222222222222222222222222222222222222222222222222222222222222';
    if (options.path.endsWith('/transactions/by_version/42')) {
      return _jsonResponse({
        'hash': '0xaptostx',
        'sender': walletAddress,
        'success': true,
        'gas_used': '100',
        'gas_unit_price': '100',
        'payload': {
          'function': '0x1::aptos_account::transfer',
          'arguments': [recipientAddress, '100000000'],
        },
      });
    }

    final body = options.data;
    final query = body is Map ? body['query']?.toString() ?? '' : '';
    if (query.contains('WalletAptosCounterparties')) {
      return _jsonResponse({
        'data': {
          'fungible_asset_activities': [
            {
              'amount': '100000000',
              'owner_address': recipientAddress,
              'transaction_version': '42',
              'type': '0x1::coin::DepositEvent',
            },
          ],
        },
      });
    }
    return _jsonResponse({
      'data': {
        'fungible_asset_activities': [
          {
            'amount': '100000000',
            'asset_type': '0x1::aptos_coin::AptosCoin',
            'block_height': '1234',
            'event_index': '0',
            'is_gas_fee': false,
            'is_transaction_success': true,
            'owner_address': walletAddress,
            'transaction_timestamp': '2026-08-15T12:00:00',
            'transaction_version': '42',
            'type': '0x1::coin::WithdrawEvent',
          },
        ],
      },
    });
  }

  ResponseBody _jsonResponse(Object data) {
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
