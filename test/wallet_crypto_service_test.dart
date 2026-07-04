import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/wallet/constants/crypto_constants.dart';
import 'package:omnicast/wallet/models/chain_balance.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/models/wallet_asset.dart';
import 'package:omnicast/wallet/models/wallet_chain.dart';
import 'package:omnicast/wallet/models/wallet_transaction_record.dart';
import 'package:omnicast/wallet/services/asset_valuation_service.dart';
import 'package:omnicast/wallet/services/chain_balance_service.dart';
import 'package:omnicast/wallet/services/transaction/wallet_block_explorer_service.dart';
import 'package:omnicast/wallet/services/transaction/transaction_history_cache.dart';
import 'package:omnicast/wallet/services/config/wallet_custom_asset_service.dart';
import 'package:omnicast/wallet/services/config/wallet_chain_config_service.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_history_api_config.dart';
import 'package:omnicast/wallet/services/crypto/wallet_secret_store.dart';
import 'package:omnicast/wallet/services/wallet_transfer_service.dart';
import 'package:omnicast/wallet/services/wallet_transaction_history_service.dart';
import 'package:omnicast/wallet/utils/asset_amount_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('formatAssetAmount', () {
    test('limits token amounts to 8 decimal places for display', () {
      expect(formatAssetAmount('1'), '1');
      expect(formatAssetAmount('1.2'), '1.2');
      expect(formatAssetAmount('1.2300000000'), '1.23');
      expect(formatAssetAmount('0.123456789'), '0.12345678');
      expect(formatAssetAmount('123.000000001'), '123');
    });
  });

  group('WalletCryptoService', () {
    late WalletCryptoService service;

    setUp(() {
      service = WalletCryptoService();
    });

    test('derives BSC, Solana, and TRON addresses from a private key', () {
      final keyPair = service.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );

      expect(keyPair.bscAddress, '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf');
      expect(keyPair.tronAddress, 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC');
      expect(
        WalletTransferService.normalizeSolanaAddress(keyPair.solanaAddress),
        keyPair.solanaAddress,
      );
    });

    test('generates and imports mnemonic wallets deterministically', () {
      final mnemonic = service.generateMnemonic();
      expect(mnemonic.split(' '), hasLength(12));

      final first = service.importMnemonic(mnemonic);
      final second = service.importMnemonic(mnemonic);

      expect(first.mnemonic, mnemonic);
      expect(first.privateKeyHex, second.privateKeyHex);
      expect(first.bscAddress, second.bscAddress);
      expect(first.tronAddress, second.tronAddress);
      expect(first.solanaAddress, second.solanaAddress);
      expect(
        WalletTransferService.normalizeSolanaAddress(first.solanaAddress),
        first.solanaAddress,
      );
    });

    test('derives Solana signing seed from mnemonic and private key', () {
      final mnemonic = service.generateMnemonic();
      final keyPair = service.importMnemonic(mnemonic);
      final mnemonicSeed = service.solanaPrivateKeyFromMnemonic(mnemonic);
      final privateKeySeed = service.solanaPrivateKeyFromPrivateKey(
        keyPair.privateKeyHex,
      );

      expect(mnemonicSeed, hasLength(32));
      expect(privateKeySeed, hasLength(32));
      expect(
        service.importPrivateKey(keyPair.privateKeyHex).solanaAddress,
        isNotEmpty,
      );
    });

    test('rejects malformed private keys', () {
      expect(() => service.importPrivateKey('abc'), throwsFormatException);
      expect(
        () => service.importPrivateKey(
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed mnemonics', () {
      expect(
        () => service.importMnemonic('alpha beta gamma'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('WalletAccount', () {
    test('does not serialize private keys to plain storage', () {
      final wallet = WalletAccount(
        id: 'wallet-1',
        name: 'Wallet 1',
        bscAddress: '0x1',
        tronAddress: 'T1',
        createdAt: DateTime.utc(2026),
        privateKeyHex: 'legacy-private-key',
      );

      expect(wallet.needsSecretMigration, isTrue);
      expect(wallet.toJson().containsKey('privateKeyHex'), isFalse);
    });
  });

  group('WalletAssetRegistry', () {
    test('serializes custom assets and merges them by contract address', () {
      const customAsset = WalletAsset(
        chain: WalletChain.bsc,
        symbol: 'CAKE',
        name: 'PancakeSwap Token',
        decimals: 18,
        contractAddress: '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
        logoUrl: 'https://example.com/cake.png',
        isCustom: true,
      );

      final decoded = WalletAsset.fromJson(customAsset.toJson());
      final merged = WalletAssetRegistry.mergeCustomAssets(WalletChain.bsc, [
        decoded,
        const WalletAsset(
          chain: WalletChain.bsc,
          symbol: 'CAKE2',
          name: 'Duplicate',
          decimals: 18,
          contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
          isCustom: true,
        ),
      ]);

      expect(decoded.isCustom, isTrue);
      expect(decoded.symbol, 'CAKE');
      expect(decoded.logoUrl, 'https://example.com/cake.png');
      expect(
        merged.where(
          (asset) => asset.contractAddress == decoded.contractAddress,
        ),
        hasLength(1),
      );
    });

    test('creates native asset for custom EVM chains', () {
      final chain = WalletChainConfig.customEvm(
        id: 'evm-137',
        name: 'Polygon',
        symbol: 'MATIC',
        rpcUrls: const ['https://polygon-rpc.com'],
        evmChainId: 137,
      );

      final assets = WalletAssetRegistry.mergeCustomAssetsForChainConfig(
        chain,
        const [],
      );

      expect(assets, hasLength(1));
      expect(assets.first.chainId, 'evm-137');
      expect(assets.first.symbol, 'MATIC');
      expect(assets.first.isNative, isTrue);
    });
  });

  group('WalletCustomAssetService', () {
    test('builds manually added assets with normalized EVM addresses', () {
      final service = WalletCustomAssetService();
      final asset = service.buildManualAsset(
        chain: WalletChain.bsc.config,
        contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
        symbol: 'cake',
        name: 'PancakeSwap Token',
        decimals: 18,
        logoUrl: 'https://example.com/cake.png',
      );

      expect(asset.symbol, 'CAKE');
      expect(
        asset.contractAddress,
        '0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
      );
      expect(asset.logoUrl, 'https://example.com/cake.png');
      expect(asset.isCustom, isTrue);
    });

    test('rejects invalid custom asset logo URLs', () {
      final service = WalletCustomAssetService();

      expect(
        () => service.buildManualAsset(
          chain: WalletChain.bsc.config,
          contractAddress: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82',
          symbol: 'cake',
          name: 'PancakeSwap Token',
          decimals: 18,
          logoUrl: 'javascript:alert(1)',
        ),
        throwsA(isA<CustomAssetInvalidInputException>()),
      );
    });

    test('provides popular assets for supported chains', () {
      final assets = WalletCustomAssetService.popularAssetsForChain(
        WalletChain.ethereum.config,
      );

      expect(assets.map((asset) => asset.symbol), contains('WETH'));
      expect(assets.first.logoUrl, isNotEmpty);
      expect(assets.every((asset) => asset.isCustom), isTrue);
    });
  });

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

  group('TransactionHistoryCache local records', () {
    test(
      'upserts local pending records and preserves updated status',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cache = TransactionHistoryCache();
        final record = WalletTransactionRecord(
          id: 'local:wallet:bsc:0xabc',
          walletId: 'wallet',
          chainId: 'bsc',
          chainName: 'BNB Smart Chain',
          symbol: 'BNB',
          assetName: 'BNB',
          walletAddress: '0x1111111111111111111111111111111111111111',
          txHash: '0xabc',
          fromAddress: '0x1111111111111111111111111111111111111111',
          toAddress: '0x2222222222222222222222222222222222222222',
          amount: '1',
          decimals: 18,
          direction: WalletTransactionDirection.outgoing,
          status: WalletTransactionStatus.pending,
          source: WalletTransactionSource.local,
          timestamp: DateTime.utc(2026),
        );

        await cache.upsertLocalRecord(record);
        await cache.upsertLocalRecord(
          record.copyWith(status: WalletTransactionStatus.success),
        );

        final records = await cache.loadLocalRecords('wallet', 'bsc', 'BNB');

        expect(records, hasLength(1));
        expect(records.single.status, WalletTransactionStatus.success);
        expect(records.single.toAddress, record.toAddress);
      },
    );
  });

  group('WalletTransactionHistoryService', () {
    test('loads BSC native transactions from Moralis', () async {
      final adapter = _FallbackRpcAdapter();
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
      final adapter = _FallbackRpcAdapter(moralisTokenFullPage: true);
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
      final adapter = _FallbackRpcAdapter();
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
      final adapter = _FallbackRpcAdapter(moralisTokenFullPage: true);
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

    test('loads EVM token transactions from explorer API', () async {
      final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
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

    test('paginates BSC token transactions from explorer API', () async {
      final adapter = _FallbackRpcAdapter(
        bscScanResultsByPage: {
          1: List.generate(
            100,
            (index) => _bscTokenTxItem(
              hash: '0xbsc-page1-$index',
              timestamp: 1700000000 - index,
            ),
          ),
          2: [_bscTokenTxItem(hash: '0xbsc-page2-old', timestamp: 1699990000)],
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
        final adapter = _FallbackRpcAdapter();
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
        final adapter = _FallbackRpcAdapter(failBscScan: true);
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
      final adapter = _FallbackRpcAdapter(failMoralisInvalidApiKey: true);
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
        final adapter = _FallbackRpcAdapter();
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
      final adapter = _FallbackRpcAdapter(xLayerTokenLogFullPage: true);
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
        final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
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
      final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
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
      final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
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
        ..httpClientAdapter = _FallbackRpcAdapter(
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
        ..httpClientAdapter = _FallbackRpcAdapter(
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
      final adapter = _FallbackRpcAdapter(
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
          ..httpClientAdapter = _FallbackRpcAdapter(
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
        ..httpClientAdapter = _FallbackRpcAdapter(
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
        ..httpClientAdapter = _FallbackRpcAdapter(failHeliusRateLimit: true);
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

  group('WalletChainConfigService', () {
    test('validates RPC chain ID before adding custom EVM chain', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      final chain = await service.addCustomEvmChain(
        name: 'Polygon',
        symbol: 'matic',
        evmChainId: 137,
        rpcUrls: const ['https://polygon-rpc.com'],
      );

      expect(chain.id, 'evm-137');
      expect(chain.symbol, 'MATIC');
      expect(chain.rpcUrls, ['https://polygon-rpc.com']);
      expect(await service.loadCustomChains(), hasLength(1));
    });

    test(
      'uses the next RPC when the first custom EVM RPC is unavailable',
      () async {
        SharedPreferences.setMockInitialValues({});
        final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
        final service = WalletChainConfigService(dio: dio);

        final chain = await service.addCustomEvmChain(
          name: 'Polygon',
          symbol: 'matic',
          evmChainId: 137,
          rpcUrls: const [
            'https://polygon-rpc-disabled.example',
            'https://polygon-bor-rpc.publicnode.com',
          ],
        );

        expect(chain.id, 'evm-137');
        expect(chain.rpcUrls.first, 'https://polygon-bor-rpc.publicnode.com');
        expect(chain.rpcUrls, contains('https://polygon-rpc-disabled.example'));
      },
    );

    test('updates custom EVM chain metadata and RPC list', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
      final service = WalletChainConfigService(dio: dio);

      final chain = await service.addCustomEvmChain(
        name: 'Polygon',
        symbol: 'matic',
        evmChainId: 137,
        rpcUrls: const ['https://polygon-rpc.com'],
      );
      final updated = await service.updateCustomEvmChain(
        chainId: chain.id,
        name: 'Polygon PoS',
        symbol: 'pol',
        rpcUrls: const [
          'https://polygon-rpc-disabled.example',
          'https://polygon-bor-rpc.publicnode.com',
        ],
      );

      expect(updated.id, chain.id);
      expect(updated.evmChainId, 137);
      expect(updated.name, 'Polygon PoS');
      expect(updated.symbol, 'POL');
      expect(updated.rpcUrls.first, 'https://polygon-bor-rpc.publicnode.com');
      expect((await service.loadCustomChains()).single.name, 'Polygon PoS');
    });

    test('updates built-in EVM chain metadata and RPC list', () async {
      SharedPreferences.setMockInitialValues({});
      final dio = Dio()..httpClientAdapter = _FallbackRpcAdapter();
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

  group('WalletSecretStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('encrypts private keys and rejects invalid passwords', () async {
      const privateKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      final store = WalletSecretStore();

      await store.savePrivateKey(
        walletId: 'wallet-1',
        password: 'secret123',
        privateKeyHex: privateKey,
      );
      await store.saveMnemonic(
        walletId: 'wallet-1',
        password: 'secret123',
        mnemonic: mnemonic,
      );

      expect(await store.hasPrivateKey('wallet-1'), isTrue);
      expect(await store.hasMnemonic('wallet-1'), isTrue);
      expect(
        await store.readPrivateKey(walletId: 'wallet-1', password: 'secret123'),
        privateKey,
      );
      expect(
        await store.readMnemonic(walletId: 'wallet-1', password: 'secret123'),
        mnemonic,
      );
      expect(
        () => store.readPrivateKey(walletId: 'wallet-1', password: 'wrong'),
        throwsA(isA<WalletSecretInvalidPasswordException>()),
      );

      final rawStorage = await const FlutterSecureStorage().readAll();
      expect(rawStorage.values.join(), isNot(contains(privateKey)));
      expect(rawStorage.values.join(), isNot(contains(mnemonic)));
    });
  });

  group('ChainBalanceService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('encodes ERC20 balanceOf calls', () {
      expect(
        ChainBalanceService.erc20BalanceOfData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        ),
        '0x70a082310000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf',
      );
    });

    test('falls back to the next EVM RPC when the primary fails', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final bnb = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.bsc.id && balance.symbol == 'BNB',
      );
      expect(bnb.amount, '1');
      expect(bnb.error, isNull);
      final sol = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.solana.id && balance.symbol == 'SOL',
      );
      expect(sol.amount, '1');
      expect(sol.error, isNull);
      expect(adapter.calls, contains('https://bsc-dataseed.bnbchain.org'));
      expect(adapter.calls, contains('https://bsc-rpc.publicnode.com'));
    });

    test('falls back to the next TRON RPC when TronGrid fails', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter(failTronGridAccount: true);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final trx = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.tron.id && balance.symbol == 'TRX',
      );
      expect(trx.amount, '1');
      expect(trx.error, isNull);
      expect(adapter.calls, contains('https://api.trongrid.io'));
      expect(adapter.calls, contains('https://tron-rpc.publicnode.com'));
    });

    test('sends TronGrid API key when loading TRON balances', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(tronGridApiKey: 'tron-key'),
      );

      await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      expect(adapter.tronGridHeaders['TRON-PRO-API-KEY'], 'tron-key');
    });

    test('uses Helius RPC first when loading Solana balances', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter();
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(
        dio: dio,
        apiConfig: const WalletHistoryApiConfig(heliusApiKey: 'helius-key'),
      );

      await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      expect(adapter.calls, contains('https://mainnet.helius-rpc.com'));
      expect(adapter.solanaRpcApiKeys, contains('helius-key'));
    });

    test('does not block all balances when Solana RPC hangs', () async {
      final dio = Dio();
      final adapter = _FallbackRpcAdapter(hangSolana: true);
      dio.httpClientAdapter = adapter;
      final service = ChainBalanceService(dio: dio);

      final balances = await service.loadBalances(
        bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
        solanaAddress: 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8',
      );

      final sol = balances.firstWhere(
        (balance) =>
            balance.chainId == WalletChain.solana.id && balance.symbol == 'SOL',
      );
      expect(sol.amount, '0');
      expect(sol.error, contains('timed out'));
      expect(
        balances.any(
          (balance) =>
              balance.chainId == WalletChain.bsc.id && balance.symbol == 'BNB',
        ),
        isTrue,
      );
    });

    test(
      'loads Solana stable token balances from associated token accounts',
      () async {
        const solanaAddress = 'H3MUoKR3cmCdodNLGfqYRfpvzgt4XNgePPzJDRB1BEd8';
        const usdtMint = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
        const usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        final usdtAta = await _solanaAssociatedTokenAddress(
          ownerAddress: solanaAddress,
          mintAddress: usdtMint,
        );
        final usdcAta = await _solanaAssociatedTokenAddress(
          ownerAddress: solanaAddress,
          mintAddress: usdcMint,
        );
        final dio = Dio();
        final adapter = _FallbackRpcAdapter(
          solanaTokenAccountBalances: {
            usdtAta: _solanaTokenBalance(amount: '1234567', decimals: 6),
            usdcAta: _solanaTokenBalance(amount: '2500000', decimals: 6),
          },
        );
        dio.httpClientAdapter = adapter;
        final service = ChainBalanceService(dio: dio);

        final balances = await service.loadBalances(
          bscAddress: '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
          tronAddress: 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
          solanaAddress: solanaAddress,
        );

        final usdt = balances.firstWhere(
          (balance) =>
              balance.chainId == WalletChain.solana.id &&
              balance.symbol == 'USDT',
        );
        final usdc = balances.firstWhere(
          (balance) =>
              balance.chainId == WalletChain.solana.id &&
              balance.symbol == 'USDC',
        );

        expect(usdt.amount, '1.234567');
        expect(usdc.amount, '2.5');
        expect(usdt.error, isNull);
        expect(usdc.error, isNull);
        expect(
          adapter.solanaMethods.where(
            (method) => method == 'getTokenAccountBalance',
          ),
          hasLength(2),
        );
      },
    );
  });

  group('AssetValuationService', () {
    late AssetValuationService service;

    setUp(() {
      service = AssetValuationService();
    });

    test('calculates total value from stable assets and injected prices', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'USDT',
            name: 'Tether USD',
            amount: '10.25',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.tron,
            symbol: 'USDC',
            name: 'USD Coin',
            amount: '5',
            address: 'T1',
          ),
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BNB',
            name: 'BNB',
            amount: '2',
            address: '0x1',
          ),
        ],
        prices: {'BNB': Decimal.parse('300')},
      );

      expect(total?.toStringAsFixed(2), '615.25');
      expect(service.formatUsdValue(total), r'$615.25');
    });

    test('calculates BTCB value with mapped BTC price', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.bsc,
            symbol: 'BTCB',
            name: 'Bitcoin BEP2',
            amount: '0.01',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.tron,
            symbol: 'TRX',
            name: 'TRON',
            amount: '100',
            address: 'T1',
          ),
        ],
        prices: {'BTCB': Decimal.parse('65000'), 'TRX': Decimal.parse('0.12')},
      );

      expect(total?.toStringAsFixed(2), '662.00');
    });

    test('calculates Ethereum chain assets with stable and wrapped prices', () {
      final total = service.calculateTotalUsdValue(
        const [
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'ETH',
            name: 'Ethereum',
            amount: '1.5',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'DAI',
            name: 'Dai Stablecoin',
            amount: '20',
            address: '0x1',
          ),
          ChainBalance(
            chain: WalletChain.ethereum,
            symbol: 'WBTC',
            name: 'Wrapped BTC',
            amount: '0.01',
            address: '0x1',
          ),
        ],
        prices: {'ETH': Decimal.parse('3000'), 'WBTC': Decimal.parse('65000')},
      );

      expect(total?.toStringAsFixed(2), '5170.00');
    });

    test('formats non-stable asset value as stable coin equivalent', () {
      final bnbText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'BNB',
          name: 'BNB',
          amount: '2',
          address: '0x1',
        ),
        prices: {'BNB': Decimal.parse('300')},
      );
      final usdtText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '100',
          address: '0x1',
        ),
      );

      expect(bnbText, '≈ 600.00 USDT');
      expect(usdtText, isNull);
    });

    test('formats zero and tiny non-stable asset values for UI display', () {
      final zeroText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'BNB',
          name: 'BNB',
          amount: '0',
          address: '0x1',
        ),
        prices: {'BNB': Decimal.parse('600')},
      );
      final tinyText = service.formatNonStableUsdValue(
        const ChainBalance(
          chain: WalletChain.ethereum,
          symbol: 'ETH',
          name: 'Ethereum',
          amount: '0.000001',
          address: '0x1',
        ),
        prices: {'ETH': Decimal.parse('1671.12')},
      );

      expect(zeroText, '≈ 0.00 USDT');
      expect(tinyText, '≈ 0.001671 USDT');
    });

    test('parses Binance prices for requested non-stable assets', () {
      final prices = service.parseBinancePrices(
        [
          {'symbol': 'BNBUSDT', 'price': '300.50'},
          {'symbol': 'TRXUSDT', 'price': '0.1201'},
          {'symbol': 'BTCUSDT', 'price': '65000'},
          {'symbol': 'OKBUSDT', 'price': '52.25'},
          {'symbol': 'SOLUSDT', 'price': '150.75'},
          {'symbol': 'ARBUSDT', 'price': '1.23'},
        ],
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toStringAsFixed(2), '300.50');
      expect(prices['TRX']?.toString(), '0.1201');
      expect(prices['BTCB']?.toString(), '65000');
      expect(prices['WBTC']?.toString(), '65000');
      expect(prices['OKB']?.toString(), '52.25');
      expect(prices['SOL']?.toString(), '150.75');
      expect(prices['ARB']?.toString(), '1.23');
    });

    test('parses single Binance ticker response', () {
      final prices = service.parseBinancePrices(
        {'symbol': 'BNBUSDT', 'price': '300.50'},
        ['BNB'],
      );

      expect(prices['BNB']?.toStringAsFixed(2), '300.50');
    });

    test('parses OKX USDT prices for requested non-stable assets', () {
      final prices = service.parseOkxPrices(
        {
          'code': '0',
          'data': [
            {'instId': 'BNB-USDT', 'last': '302.1'},
            {'instId': 'TRX-USDT', 'last': '0.1208'},
            {'instId': 'BTC-USDT', 'last': '65100'},
            {'instId': 'OKB-USDT', 'last': '52.4'},
            {'instId': 'SOL-USDT', 'last': '151.2'},
            {'instId': 'ARB-USDT', 'last': '1.24'},
          ],
        },
        ['BNB', 'TRX', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '302.1');
      expect(prices['TRX']?.toString(), '0.1208');
      expect(prices['BTCB']?.toString(), '65100');
      expect(prices['WBTC']?.toString(), '65100');
      expect(prices['OKB']?.toString(), '52.4');
      expect(prices['SOL']?.toString(), '151.2');
      expect(prices['ARB']?.toString(), '1.24');
    });

    test('parses requested prices from OKX full spot ticker response', () {
      final prices = service.parseOkxPrices(
        {
          'code': '0',
          'data': [
            {'instId': 'DOGE-USDT', 'last': '0.11'},
            {'instId': 'BNB-USDT', 'last': '575.3'},
            {'instId': 'BTC-USDT', 'last': '60920.7'},
            {'instId': 'OKB-USDT', 'last': '68.62'},
          ],
        },
        ['BNB', 'BTCB', 'OKB'],
      );

      expect(prices['BNB']?.toString(), '575.3');
      expect(prices['BTCB']?.toString(), '60920.7');
      expect(prices['OKB']?.toString(), '68.62');
      expect(prices.containsKey('DOGE'), isFalse);
    });

    test('parses CoinGecko fallback prices by wallet symbol', () {
      final prices = service.parseCoinGeckoPrices(
        {
          'binancecoin': {'usd': 301.25},
          'tron': {'usd': 0.119},
          'ethereum': {'usd': '3500.5'},
          'bitcoin': {'usd': 64999.99},
          'okb': {'usd': 52.3},
          'solana': {'usd': 150.8},
          'arbitrum': {'usd': 1.25},
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '301.25');
      expect(prices['TRX']?.toString(), '0.119');
      expect(prices['ETH']?.toString(), '3500.5');
      expect(prices['BTCB']?.toString(), '64999.99');
      expect(prices['WBTC']?.toString(), '64999.99');
      expect(prices['OKB']?.toString(), '52.3');
      expect(prices['SOL']?.toString(), '150.8');
      expect(prices['ARB']?.toString(), '1.25');
    });

    test('parses DeFiLlama prices by CoinGecko ids', () {
      final prices = service.parseDefiLlamaPrices(
        {
          'coins': {
            'coingecko:binancecoin': {'price': 600.21},
            'coingecko:bitcoin': {'price': '62722.09'},
            'coingecko:ethereum': {'price': 1671.12},
            'coingecko:solana': {'price': 66.16},
            'coingecko:arbitrum': {'price': 1.26},
          },
        },
        ['BNB', 'BTCB', 'WBTC', 'ETH', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '600.21');
      expect(prices['BTCB']?.toString(), '62722.09');
      expect(prices['WBTC']?.toString(), '62722.09');
      expect(prices['ETH']?.toString(), '1671.12');
      expect(prices['SOL']?.toString(), '66.16');
      expect(prices['ARB']?.toString(), '1.26');
    });

    test('parses CoinPaprika fallback prices by wallet symbol', () {
      final prices = service.parseCoinPaprikaPrices(
        [
          {
            'id': 'bnb-binance-coin',
            'quotes': {
              'USD': {'price': 599.93},
            },
          },
          {
            'id': 'btc-bitcoin',
            'quotes': {
              'USD': {'price': '62643.07'},
            },
          },
          {
            'id': 'sol-solana',
            'quotes': {
              'USD': {'price': 66.14},
            },
          },
          {
            'id': 'arb-arbitrum',
            'quotes': {
              'USD': {'price': 1.27},
            },
          },
        ],
        ['BNB', 'BTCB', 'WBTC', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '599.93');
      expect(prices['BTCB']?.toString(), '62643.07');
      expect(prices['WBTC']?.toString(), '62643.07');
      expect(prices['SOL']?.toString(), '66.14');
      expect(prices['ARB']?.toString(), '1.27');
    });

    test('parses CryptoCompare fallback prices by wallet symbol', () {
      final prices = service.parseCryptoComparePrices(
        {
          'BNB': {'USD': 574.65},
          'TRX': {'USD': 0.3202},
          'ETH': {'USD': 1566.43},
          'BTC': {'USD': 60913.71},
          'OKB': {'USD': 69.12},
          'SOL': {'USD': 151.4},
          'ARB': {'USD': 1.28},
        },
        ['BNB', 'TRX', 'ETH', 'BTCB', 'WBTC', 'OKB', 'SOL', 'ARB'],
      );

      expect(prices['BNB']?.toString(), '574.65');
      expect(prices['TRX']?.toString(), '0.3202');
      expect(prices['ETH']?.toString(), '1566.43');
      expect(prices['BTCB']?.toString(), '60913.71');
      expect(prices['WBTC']?.toString(), '60913.71');
      expect(prices['OKB']?.toString(), '69.12');
      expect(prices['SOL']?.toString(), '151.4');
      expect(prices['ARB']?.toString(), '1.28');
    });

    test('uses stable coin prices without external price data', () {
      final total = service.calculateTotalUsdValue(const [
        ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'USDT',
          name: 'Tether USD',
          amount: '0',
          address: '0x1',
        ),
      ]);

      expect(service.formatUsdValue(total), r'$0.00');
    });

    test('returns null when no asset has a known USD price', () {
      final total = service.calculateTotalUsdValue(const [
        ChainBalance(
          chain: WalletChain.bsc,
          symbol: 'UNKNOWN',
          name: 'Unknown Token',
          amount: '100',
          address: '0x1',
        ),
      ]);

      expect(total, isNull);
      expect(service.formatUsdValue(total), '--');
    });
  });

  group('WalletTransferService', () {
    test('converts decimal amounts to raw units', () {
      expect(
        WalletTransferService.amountToRawUnits('1.25', 18).toString(),
        '1250000000000000000',
      );
      expect(
        WalletTransferService.amountToRawUnits('0.000001', 6).toString(),
        '1',
      );
      expect(
        () => WalletTransferService.amountToRawUnits('0.0000001', 6),
        throwsFormatException,
      );
    });

    test('formats raw fee units for display', () {
      expect(
        WalletTransferService.rawUnitsToAmount(
          BigInt.from(21000) * BigInt.from(3000000000),
          18,
        ),
        '0.000063',
      );
      expect(
        WalletTransferService.rawUnitsToAmount(BigInt.from(30000000), 6),
        '30',
      );
    });

    test('encodes ERC20 transfer data', () {
      expect(
        WalletTransferService.erc20TransferData(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
          BigInt.from(1000000),
        ),
        '0xa9059cbb0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('defines Ethereum, X Layer, and Arbitrum as EVM chains', () {
      expect(WalletChain.ethereum.evmChainId, 1);
      expect(WalletChain.ethereum.symbol, 'ETH');
      expect(WalletChain.xLayer.evmChainId, 196);
      expect(WalletChain.xLayer.symbol, 'OKB');
      expect(WalletChain.arbitrum.evmChainId, 42161);
      expect(WalletChain.arbitrum.symbol, 'ETH');
      expect(WalletChain.solana.evmChainId, isNull);
      expect(WalletChain.solana.symbol, 'SOL');
      expect(
        WalletTransferService.normalizeBscAddress(
          '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
        ),
        '0x7e5f4552091a69125d5dfcb7b8c2659029395bdf',
      );
    });

    test('encodes TRC20 transfer parameters', () {
      expect(
        WalletTransferService.trc20TransferParameter(
          'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
          BigInt.from(1000000),
        ),
        '0000000000000000000000007e5f4552091a69125d5dfcb7b8c2659029395bdf00000000000000000000000000000000000000000000000000000000000f4240',
      );
    });

    test('submits native Solana transfer through RPC', () async {
      final adapter = _FallbackRpcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
          keyPair.privateKeyHex,
        ),
        asset: ChainBalance(
          chain: WalletChain.solana,
          symbol: 'SOL',
          name: 'Solana',
          amount: '1',
          address: keyPair.solanaAddress,
          decimals: 9,
        ),
        toAddress: '11111111111111111111111111111111',
        amount: '0.001',
      );

      expect(hash, 'solana-signature');
      expect(adapter.solanaMethods, contains('getLatestBlockhash'));
      expect(adapter.solanaMethods, contains('sendTransaction'));
      expect(adapter.lastSolanaTransactionBase64, isNotEmpty);
      expect(
        base64Decode(adapter.lastSolanaTransactionBase64!).length,
        greaterThan(100),
      );
    });

    test('submits SPL token transfer through RPC', () async {
      final cryptoService = WalletCryptoService();
      final keyPair = cryptoService.importPrivateKey(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
      );
      final sourceTokenAccount = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000002',
          )
          .solanaAddress;
      final recipient = cryptoService
          .importPrivateKey(
            '0x0000000000000000000000000000000000000000000000000000000000000003',
          )
          .solanaAddress;
      final adapter = _FallbackRpcAdapter(
        solanaTokenAccountPubkey: sourceTokenAccount,
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final transferService = WalletTransferService(dio: dio);

      final hash = await transferService.transfer(
        privateKeyHex: keyPair.privateKeyHex,
        solanaPrivateKey: cryptoService.solanaPrivateKeyFromPrivateKey(
          keyPair.privateKeyHex,
        ),
        asset: ChainBalance(
          chain: WalletChain.solana,
          symbol: 'USDC',
          name: 'USD Coin',
          amount: '10',
          address: keyPair.solanaAddress,
          contractAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          decimals: 6,
        ),
        toAddress: recipient,
        amount: '1.25',
      );

      expect(hash, 'solana-signature');
      expect(adapter.solanaMethods, contains('getTokenAccountsByOwner'));
      expect(adapter.solanaMethods, contains('getLatestBlockhash'));
      expect(adapter.solanaMethods, contains('sendTransaction'));
      expect(adapter.lastSolanaTransactionBase64, isNotEmpty);
      expect(
        base64Decode(adapter.lastSolanaTransactionBase64!).length,
        greaterThan(180),
      );
    });
  });
}

Map<String, dynamic> _bscTokenTxItem({
  required String hash,
  required int timestamp,
}) {
  return {
    'blockNumber': timestamp.toString(),
    'timeStamp': timestamp.toString(),
    'hash': hash,
    'from': '0x1111111111111111111111111111111111111111',
    'to': '0x2222222222222222222222222222222222222222',
    'value': '2000000000000000000',
    'tokenDecimal': '18',
    'gasUsed': '21000',
    'gasPrice': '1000000000',
    'contractAddress': '0x55d398326f99059fF775485246999027B3197955',
  };
}

Map<String, dynamic> _moralisTokenTxItem({
  required String hash,
  required String value,
  String contractAddress = '0x55d398326f99059fF775485246999027B3197955',
  String tokenDecimals = '18',
  String timestamp = '2026-06-01T12:00:00.000Z',
  int logIndex = 1,
}) {
  return {
    'token_name': 'Tether USD',
    'token_symbol': 'USDT',
    'token_decimals': tokenDecimals,
    'transaction_hash': hash,
    'address': contractAddress,
    'block_timestamp': timestamp,
    'block_number': 123,
    'from_address': '0x1111111111111111111111111111111111111111',
    'to_address': '0x2222222222222222222222222222222222222222',
    'value': value,
    'log_index': logIndex,
  };
}

Map<String, dynamic> _xLayerTokenLog(
  String hash,
  int blockNumber,
  int logIndex,
) {
  const walletTopic =
      '0x0000000000000000000000001111111111111111111111111111111111111111';
  const recipientTopic =
      '0x0000000000000000000000002222222222222222222222222222222222222222';
  return {
    'transactionHash': hash,
    'blockNumber': '0x${blockNumber.toRadixString(16)}',
    'logIndex': '0x${logIndex.toRadixString(16)}',
    'data': '0x1bc16d674ec80000',
    'topics': [
      CryptoConstants.evmTransferEventTopic,
      walletTopic,
      recipientTopic,
    ],
  };
}

class _FallbackRpcAdapter implements HttpClientAdapter {
  _FallbackRpcAdapter({
    this.failBscScan = false,
    this.failTronGridAccount = false,
    this.hangSolana = false,
    this.solanaTokenAccountPubkey,
    this.solanaTokenAccountBalances = const {},
    this.solanaHistoryOwner,
    this.solanaHistoryRecipient,
    this.heliusOwner,
    this.heliusRecipient,
    this.heliusMint,
    this.heliusFullPage = false,
    this.failHeliusRateLimit = false,
    this.failMoralisInvalidApiKey = false,
    this.heliusUseAccountData = false,
    this.bscScanResultsByPage,
    this.moralisTokenFullPage = false,
    this.xLayerTokenLogFullPage = false,
  });

  final bool failBscScan;
  final bool failTronGridAccount;
  final bool hangSolana;
  final String? solanaTokenAccountPubkey;
  final Map<String, Map<String, dynamic>> solanaTokenAccountBalances;
  final String? solanaHistoryOwner;
  final String? solanaHistoryRecipient;
  final String? heliusOwner;
  final String? heliusRecipient;
  final String? heliusMint;
  final bool heliusFullPage;
  final bool failHeliusRateLimit;
  final bool failMoralisInvalidApiKey;
  final bool heliusUseAccountData;
  final Map<int, List<Map<String, dynamic>>>? bscScanResultsByPage;
  final bool moralisTokenFullPage;
  final bool xLayerTokenLogFullPage;
  final calls = <String>[];
  final bscScanPages = <int>[];
  final bscScanOffsets = <int>[];
  final moralisChains = <String>[];
  final moralisCursors = <String>[];
  final moralisContractFilters = <List<String>>[];
  final xLayerLogRanges = <(int, int)>[];
  final etherscanV2ChainIds = <String>[];
  final solanaMethods = <String>[];
  final solanaRpcApiKeys = <String>[];
  Map<String, dynamic> tronGridHeaders = const {};
  String? lastSolanaTransactionBase64;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final origin = '${options.uri.scheme}://${options.uri.host}';
    calls.add(origin);

    if (origin == 'https://deep-index.moralis.io') {
      if (failMoralisInvalidApiKey) {
        return _jsonResponse({'message': 'invalid api key'}, statusCode: 403);
      }
      moralisChains.add(options.uri.queryParameters['chain'] ?? '');
      final cursor = options.uri.queryParameters['cursor'] ?? '';
      moralisCursors.add(cursor);
      final contractFilters =
          options.uri.queryParametersAll['contract_addresses'] ?? const [];
      final contractAddress = contractFilters.isNotEmpty
          ? contractFilters.first
          : '0x55d398326f99059fF775485246999027B3197955';
      if (contractFilters.isNotEmpty) {
        moralisContractFilters.add(contractFilters);
      }
      if (options.uri.path.endsWith('/erc20/transfers')) {
        if (cursor == 'moralis-next') {
          return _jsonResponse({
            'result': [
              _moralisTokenTxItem(
                hash: '0xmoralis-token-next',
                value: '3000000000000000000',
                contractAddress: contractAddress,
              ),
            ],
            'cursor': null,
          });
        }
        final count = moralisTokenFullPage ? 30 : 1;
        return _jsonResponse({
          'result': List.generate(
            count,
            (index) => _moralisTokenTxItem(
              hash: '0xmoralis-token-$index',
              value: '2000000000000000000',
              contractAddress: contractAddress,
              timestamp:
                  '2026-06-01T12:00:${index.toString().padLeft(2, '0')}Z',
              logIndex: index,
            ),
          ),
          'cursor': moralisTokenFullPage ? 'moralis-next' : null,
        });
      }
      return _jsonResponse({
        'result': [
          {
            'hash': '0xmoralisnative',
            'from_address': '0x2222222222222222222222222222222222222222',
            'to_address': '0x1111111111111111111111111111111111111111',
            'value': '1250000000000000000',
            'gas_price': '1000000000',
            'receipt_gas_used': '21000',
            'receipt_status': '1',
            'transaction_fee': '0.000021',
            'block_number': 123,
            'block_timestamp': '2026-06-01T12:00:00.000Z',
          },
        ],
        'cursor': null,
      });
    }

    if (origin == 'https://api.helius.xyz') {
      if (failHeliusRateLimit) {
        return _jsonResponse({'error': 'rate limited'}, statusCode: 429);
      }
      final owner = heliusOwner ?? '';
      final other = heliusRecipient ?? '';
      final mint = heliusMint ?? '';
      if (heliusUseAccountData && mint.isEmpty) {
        return _jsonResponse([
          {
            'signature': 'helius-sol-account-data',
            'timestamp': 1700000000,
            'slot': 123,
            'fee': 5000,
            'transactionError': null,
            'nativeTransfers': [],
            'accountData': [
              {'account': owner, 'nativeBalanceChange': -250000000},
            ],
          },
        ]);
      }
      if (heliusUseAccountData && mint.isNotEmpty) {
        return _jsonResponse([
          {
            'signature': 'helius-token-account-data',
            'timestamp': 1700000000,
            'slot': 123,
            'fee': 5000,
            'transactionError': null,
            'tokenTransfers': [],
            'accountData': [
              {
                'account': owner,
                'nativeBalanceChange': 0,
                'tokenBalanceChanges': [
                  {
                    'userAccount': owner,
                    'mint': mint,
                    'rawTokenAmount': {'tokenAmount': '2500000', 'decimals': 6},
                  },
                ],
              },
            ],
          },
        ]);
      }
      if (mint.isNotEmpty) {
        final count = heliusFullPage ? 50 : 1;
        return _jsonResponse(
          List.generate(count, (index) {
            return {
              'signature': 'helius-token-signature-$index',
              'timestamp': 1700000000 - index,
              'slot': 123 - index,
              'fee': 5000,
              'transactionError': null,
              'tokenTransfers': [
                {
                  'fromUserAccount': other,
                  'toUserAccount': owner,
                  'mint': mint,
                  'tokenAmount': 2.5,
                  'rawTokenAmount': {'tokenAmount': '2500000', 'decimals': 6},
                },
              ],
            };
          }),
        );
      }
      return _jsonResponse([
        {
          'signature': 'helius-sol-signature',
          'timestamp': 1700000000,
          'slot': 123,
          'fee': 5000,
          'transactionError': null,
          'nativeTransfers': [
            {
              'fromUserAccount': owner,
              'toUserAccount': other,
              'amount': 1250000000,
            },
          ],
        },
      ]);
    }

    if (origin == 'https://bsc-dataseed.bnbchain.org') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32000, 'message': 'temporary upstream error'},
      });
    }

    if (origin == 'https://bsc-rpc.publicnode.com') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmChainIdRequest(options.data)
            ? '0x38'
            : _isEvmNativeRequest(options.data)
            ? '0x0de0b6b3a7640000'
            : '0x0',
      });
    }

    if (origin == 'https://api.bscscan.com' && options.uri.path == '/api') {
      final page = int.tryParse(options.uri.queryParameters['page'] ?? '') ?? 1;
      final offset =
          int.tryParse(options.uri.queryParameters['offset'] ?? '') ?? 0;
      bscScanPages.add(page);
      bscScanOffsets.add(offset);
      if (failBscScan) {
        return _jsonResponse({
          'status': '0',
          'message': 'NOTOK',
          'result': 'Explorer unavailable',
        });
      }
      final pageResults = bscScanResultsByPage?[page];
      if (pageResults != null) {
        return _jsonResponse({
          'status': pageResults.isEmpty ? '0' : '1',
          'message': pageResults.isEmpty ? 'No transactions found' : 'OK',
          'result': pageResults.isEmpty ? 'No transactions found' : pageResults,
        });
      }
      return _jsonResponse({
        'status': '1',
        'message': 'OK',
        'result': [
          {
            'blockNumber': '123',
            'timeStamp': '1700000000',
            'hash': '0xbeef',
            'from': '0x1111111111111111111111111111111111111111',
            'to': '0x2222222222222222222222222222222222222222',
            'value': '2000000000000000000',
            'tokenDecimal': '18',
            'gasUsed': '21000',
            'gasPrice': '1000000000',
            'contractAddress': '0x55d398326f99059fF775485246999027B3197955',
          },
        ],
      });
    }

    if (origin == 'https://api.etherscan.io' && options.uri.path == '/v2/api') {
      etherscanV2ChainIds.add(options.uri.queryParameters['chainid'] ?? '');
      return _jsonResponse({
        'status': '1',
        'message': 'OK',
        'result': [
          _bscTokenTxItem(hash: '0xetherscanv2bsc', timestamp: 1700000000),
        ],
      });
    }

    if (origin == 'https://api.etherscan.io' && options.uri.path == '/api') {
      return _jsonResponse({
        'status': '0',
        'message': 'NOTOK',
        'result': 'Missing/Invalid API Key',
      });
    }

    if (origin == 'https://eth.blockscout.com' &&
        options.uri.path.endsWith('/transactions')) {
      return _jsonResponse({
        'items': [
          {
            'hash': '0xblocknative',
            'from': {'hash': '0x2222222222222222222222222222222222222222'},
            'to': {'hash': '0x1111111111111111111111111111111111111111'},
            'value': '100000000000000000',
            'fee': {'value': '21000000000000'},
            'status': 'ok',
            'result': 'success',
            'block_number': 123,
            'timestamp': '2026-06-01T12:00:00.000000Z',
          },
        ],
        'next_page_params': null,
      });
    }

    if (origin == 'https://eth.blockscout.com' &&
        options.uri.path.endsWith('/token-transfers')) {
      return _jsonResponse({
        'items': [
          {
            'transaction_hash': '0xwrongtoken',
            'from': {'hash': '0x2222222222222222222222222222222222222222'},
            'to': {'hash': '0x1111111111111111111111111111111111111111'},
            'token': {
              'address_hash': '0x0000000000000000000000000000000000000000',
              'decimals': '18',
            },
            'total': {'decimals': '18', 'value': '1'},
            'log_index': 1,
            'block_number': 122,
            'timestamp': '2026-06-01T11:00:00.000000Z',
          },
          {
            'transaction_hash': '0xblocktoken',
            'from': {'hash': '0x1111111111111111111111111111111111111111'},
            'to': {'hash': '0x2222222222222222222222222222222222222222'},
            'token': {
              'address_hash': '0xdAC17F958D2ee523a2206206994597C13D831ec7',
              'decimals': '6',
            },
            'total': {'decimals': '6', 'value': '2500000'},
            'log_index': 2,
            'block_number': 124,
            'timestamp': '2026-06-01T12:30:00.000000Z',
          },
        ],
        'next_page_params': null,
      });
    }

    if (origin == 'https://rpc.xlayer.tech') {
      final method = _evmMethod(options.data);
      if (method == 'eth_blockNumber') {
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0xf4240'});
      }
      if (method == 'eth_getLogs') {
        final filter = _firstEvmParamMap(options.data);
        final fromBlock = _hexToInt(filter['fromBlock']?.toString() ?? '0x0');
        final toBlock = _hexToInt(filter['toBlock']?.toString() ?? '0x0');
        final topics = filter['topics'];
        final isOutgoing =
            topics is List && topics.length > 1 && topics[1] != null;
        if (isOutgoing) {
          xLayerLogRanges.add((fromBlock, toBlock));
          if (toBlock == 500000) {
            return _jsonResponse({
              'jsonrpc': '2.0',
              'id': 1,
              'result': [_xLayerTokenLog('0xxlayerold', 499999, 1)],
            });
          }
          if (xLayerTokenLogFullPage && toBlock == 1000000) {
            return _jsonResponse({
              'jsonrpc': '2.0',
              'id': 1,
              'result': List.generate(
                30,
                (index) =>
                    _xLayerTokenLog('0xxlayer$index', 1000000 - index, index),
              ),
            });
          }
        }
        return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': []});
      }
      if (method == 'eth_getTransactionReceipt') {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'status': '0x1',
            'gasUsed': '0x5208',
            'effectiveGasPrice': '0x3b9aca00',
          },
        });
      }
      if (method == 'eth_getBlockByNumber') {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'timestamp': '0x6553f100'},
        });
      }
      return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x0'});
    }

    if (origin == 'https://ethereum-rpc.publicnode.com' ||
        origin == 'https://arbitrum-one-rpc.publicnode.com' ||
        origin == 'https://arbitrum.llamarpc.com' ||
        origin == 'https://arb1.arbitrum.io') {
      return _jsonResponse({'jsonrpc': '2.0', 'id': 1, 'result': '0x0'});
    }

    if (origin == 'https://polygon-rpc.com') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmChainIdRequest(options.data) ? '0x89' : '0x0',
      });
    }

    if (origin == 'https://polygon-rpc-disabled.example') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32051, 'message': 'API key disabled'},
      });
    }

    if (origin == 'https://polygon-bor-rpc.publicnode.com') {
      return _jsonResponse({
        'jsonrpc': '2.0',
        'id': 1,
        'result': _isEvmChainIdRequest(options.data) ? '0x89' : '0x0',
      });
    }

    if (origin == 'https://solana-mainnet.rpc.extrnode.com' ||
        origin == 'https://rpc.ankr.com' ||
        origin == 'https://solana-rpc.publicnode.com' ||
        origin == 'https://api.mainnet-beta.solana.com' ||
        origin == 'https://mainnet.helius-rpc.com') {
      if (hangSolana) {
        throw TimeoutException('Solana balance lookup timed out');
      }
      final apiKey = options.uri.queryParameters['api-key'];
      if (apiKey != null && apiKey.isNotEmpty) {
        solanaRpcApiKeys.add(apiKey);
      }
      final method = _solanaMethod(options.data);
      if (method != null) {
        solanaMethods.add(method);
      }
      if (_isSolanaMethod(options.data, 'getBalance')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'value': 1000000000},
        });
      }
      if (_isSolanaMethod(options.data, 'getTokenAccountBalance')) {
        final account = _firstSolanaParam(options.data);
        final tokenBalance = solanaTokenAccountBalances[account];
        if (tokenBalance == null) {
          return _jsonResponse({
            'jsonrpc': '2.0',
            'id': 1,
            'error': {'code': -32602, 'message': 'could not find account'},
          });
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {'value': tokenBalance},
        });
      }
      if (_isSolanaMethod(options.data, 'getTokenAccountsByOwner')) {
        final pubkey = solanaTokenAccountPubkey;
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'value': pubkey == null
                ? []
                : [
                    {'pubkey': pubkey},
                  ],
          },
        });
      }
      if (_isSolanaMethod(options.data, 'getLatestBlockhash')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'context': {'slot': 1},
            'value': {
              'blockhash': '11111111111111111111111111111111',
              'lastValidBlockHeight': 1,
            },
          },
        });
      }
      if (_isSolanaMethod(options.data, 'getSignaturesForAddress')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': [
            {'signature': 'solana-history-signature'},
          ],
        });
      }
      if (_isSolanaMethod(options.data, 'getParsedTransaction')) {
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'blockTime': 1700000000,
            'meta': {'err': null, 'fee': 5000},
            'transaction': {
              'message': {
                'instructions': [
                  {
                    'program': 'system',
                    'parsed': {
                      'type': 'transfer',
                      'info': {
                        'source': solanaHistoryOwner ?? '',
                        'destination': solanaHistoryRecipient ?? '',
                        'lamports': 1250000000,
                      },
                    },
                  },
                ],
              },
            },
          },
        });
      }
      if (_isSolanaMethod(options.data, 'sendTransaction')) {
        final params = options.data is Map ? options.data['params'] : null;
        if (params is List && params.isNotEmpty && params.first is String) {
          lastSolanaTransactionBase64 = params.first as String;
        }
        return _jsonResponse({
          'jsonrpc': '2.0',
          'id': 1,
          'result': 'solana-signature',
        });
      }
    }

    if (origin == 'https://api.trongrid.io' &&
        options.uri.path == '/wallet/getaccount') {
      tronGridHeaders = options.headers;
      if (failTronGridAccount) {
        return _jsonResponse({
          'Error': 'temporary upstream error',
        }, statusCode: 500);
      }
      return _jsonResponse({'balance': 0});
    }

    if (origin == 'https://tron-rpc.publicnode.com' &&
        options.uri.path == '/wallet/getaccount') {
      return _jsonResponse({'balance': 1000000});
    }

    if (origin == 'https://api.trongrid.io' &&
        options.uri.path.startsWith('/v1/accounts/')) {
      if (options.uri.path.endsWith('/transactions/trc20')) {
        return _jsonResponse({
          'data': [
            {
              'transaction_id': 'tronhash1',
              'from': 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
              'to': 'TKn1ErhSZJD7GBuVxMqowPJ7YxXQwfGKEp',
              'value': '2500000',
              'token_info': {'decimals': 6},
              'block_timestamp': 1700000000000,
            },
          ],
        });
      }
      return _jsonResponse({'data': []});
    }

    return _jsonResponse({}, statusCode: 404);
  }

  bool _isEvmNativeRequest(dynamic data) {
    return data is Map && data['method'] == 'eth_getBalance';
  }

  bool _isEvmChainIdRequest(dynamic data) {
    return data is Map && data['method'] == 'eth_chainId';
  }

  String? _evmMethod(dynamic data) {
    return data is Map ? data['method']?.toString() : null;
  }

  Map<dynamic, dynamic> _firstEvmParamMap(dynamic data) {
    final params = data is Map ? data['params'] : null;
    if (params is List && params.isNotEmpty && params.first is Map) {
      return params.first as Map;
    }
    return const {};
  }

  int _hexToInt(String value) {
    final normalized = value.replaceFirst('0x', '');
    if (normalized.isEmpty) return 0;
    return int.parse(normalized, radix: 16);
  }

  bool _isSolanaMethod(dynamic data, String method) {
    return data is Map && data['method'] == method;
  }

  String? _solanaMethod(dynamic data) {
    return data is Map ? data['method']?.toString() : null;
  }

  String? _firstSolanaParam(dynamic data) {
    final params = data is Map ? data['params'] : null;
    if (params is! List || params.isEmpty) {
      return null;
    }
    return params.first?.toString();
  }

  ResponseBody _jsonResponse(Object data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<String> _solanaAssociatedTokenAddress({
  required String ownerAddress,
  required String mintAddress,
}) async {
  final owner = Ed25519HDPublicKey.fromBase58(ownerAddress);
  final mint = Ed25519HDPublicKey.fromBase58(mintAddress);
  final ata = await findAssociatedTokenAddress(owner: owner, mint: mint);
  return ata.toBase58();
}

Map<String, dynamic> _solanaTokenBalance({
  required String amount,
  required int decimals,
}) {
  return {'amount': amount, 'decimals': decimals};
}
