import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:sui/sui.dart';

import '../adapters/chain_adapter.dart';
import '../adapters/chain_adapter_registry.dart';
import '../adapters/chain_operation_registry.dart';
import '../adapters/default_chain_adapter_registry.dart';
import '../constants/crypto_constants.dart';
import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_account.dart';
import '../models/wallet_transaction_record.dart';
import '../utils/rpc_retry_helper.dart';
import '../../utils/safe_log.dart';
import 'wallet_history_api_config.dart';
import 'wallet_transfer_service.dart';

part 'transaction_history/transaction_history_provider_helpers.dart';
part 'transaction_history/transaction_history_models.dart';
part 'transaction_history/evm_history_provider_types.dart';
part 'transaction_history/evm_history_provider_routing.dart';
part 'transaction_history/evm_history_paginator.dart';
part 'transaction_history/evm_transaction_history_provider.dart';
part 'transaction_history/evm_explorer_history_client.dart';
part 'transaction_history/evm_rpc_history_provider.dart';
part 'transaction_history/evm_transaction_record_parsers.dart';
part 'transaction_history/moralis_evm_transaction_history_provider.dart';
part 'transaction_history/tron_transaction_history_provider.dart';
part 'transaction_history/solana_helius_history_helpers.dart';
part 'transaction_history/solana_helius_transaction_parser.dart';
part 'transaction_history/solana_helius_history_provider.dart';
part 'transaction_history/solana_transaction_history_provider.dart';
part 'transaction_history/solana_rpc_client.dart';
part 'transaction_history/solana_token_account_client.dart';
part 'transaction_history/solana_transaction_record_parser.dart';
part 'transaction_history/solana_rpc_history_provider.dart';
part 'transaction_history/bitcoin_transaction_history_provider.dart';
part 'transaction_history/sui_transaction_history_provider.dart';
part 'transaction_history/aptos_transaction_history_provider.dart';

typedef ChainTransactionLookup =
    Future<WalletTransactionRecord?> Function({
      required String walletId,
      required ChainBalance asset,
      required String txHash,
    });

typedef ChainHistoryPageLoader =
    Future<TransactionHistoryPageResult> Function({
      required String walletId,
      required ChainBalance asset,
      required TransactionHistoryCursor? cursor,
    });

/// 钱包链上交易记录服务。
///
/// 对外保持统一入口；实际按链类型委托给 EVM、TRON、Solana Provider。
class WalletTransactionHistoryService {
  WalletTransactionHistoryService({
    Dio? dio,
    WalletHistoryApiConfig? apiConfig,
    ChainAdapterRegistry? adapterRegistry,
    Map<String, ChainTransactionLookup> transactionLookups = const {},
    Map<String, ChainHistoryPageLoader> historyPageLoaders = const {},
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: _requestTimeout,
               receiveTimeout: _requestTimeout,
               sendTimeout: _requestTimeout,
             ),
           ),
       _apiConfig = apiConfig ?? const WalletHistoryApiConfig(),
       _adapterRegistry =
           adapterRegistry ?? createDefaultChainAdapterRegistry() {
    _evmProvider = _EvmHistoryCoordinator(dio: _dio, apiConfig: _apiConfig);
    _moralisEvmProvider = _MoralisEvmTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _tronProvider = _TronTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _solanaProvider = _SolanaHistoryCoordinator(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _bitcoinProvider = _BitcoinTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _suiProvider = _SuiTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _aptosProvider = _AptosTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _transactionLookups = ChainOperationRegistry({
      WalletAddressNamespace.evm: _lookupEvmTransaction,
      WalletAddressNamespace.bitcoin: _lookupBitcoinTransaction,
      WalletAddressNamespace.sui: _lookupSuiTransaction,
      WalletAddressNamespace.aptos: _lookupAptosTransaction,
      ...transactionLookups,
    });
    _historyPageLoaders = ChainOperationRegistry({
      WalletAddressNamespace.evm: _loadEvmRecordPage,
      WalletAddressNamespace.tron: _loadTronRecordPage,
      WalletAddressNamespace.solana: _loadSolanaRecordPage,
      WalletAddressNamespace.bitcoin: _loadBitcoinRecordPage,
      WalletAddressNamespace.sui: _loadSuiRecordPage,
      WalletAddressNamespace.aptos: _loadAptosRecordPage,
      ...historyPageLoaders,
    });
  }

  /// HTTP/RPC 请求客户端。
  final Dio _dio;

  final WalletHistoryApiConfig _apiConfig;
  final ChainAdapterRegistry _adapterRegistry;

  late final _EvmHistoryCoordinator _evmProvider;
  late final _MoralisEvmTransactionHistoryProvider _moralisEvmProvider;
  late final _TronTransactionHistoryProvider _tronProvider;
  late final _SolanaHistoryCoordinator _solanaProvider;
  late final _BitcoinTransactionHistoryProvider _bitcoinProvider;
  late final _SuiTransactionHistoryProvider _suiProvider;
  late final _AptosTransactionHistoryProvider _aptosProvider;
  late final ChainOperationRegistry<ChainTransactionLookup> _transactionLookups;
  late final ChainOperationRegistry<ChainHistoryPageLoader> _historyPageLoaders;

  static const Duration _requestTimeout = Duration(seconds: 6);

  /// 读取某个钱包、某条链、某个币种的链上交易记录。
  ///
  /// [walletId] 仅用于生成页面内稳定的记录 ID，不再用于本地存储隔离。
  Future<List<WalletTransactionRecord>> loadAssetRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final result = await loadAssetRecordPage(walletId: walletId, asset: asset);
    return result.records;
  }

  /// 按交易 hash 读取单条链上交易记录。
  Future<WalletTransactionRecord?> loadTransactionRecordByHash({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) async {
    final chain = asset.chainRef;
    final lookup = _transactionLookups.require(
      chain,
      _adapterRegistry,
      capability: ChainCapability.history,
    );
    return lookup(walletId: walletId, asset: asset, txHash: txHash);
  }

  /// 分页读取某个资产的链上交易记录。
  Future<TransactionHistoryPageResult> loadAssetRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final chain = asset.chainRef;
    final loader = _historyPageLoaders.require(
      chain,
      _adapterRegistry,
      capability: ChainCapability.history,
    );
    return loader(walletId: walletId, asset: asset, cursor: cursor);
  }

  Future<WalletTransactionRecord?> _lookupEvmTransaction({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) => _evmProvider.loadRecordByTransactionHash(
    walletId: walletId,
    asset: asset,
    txHash: txHash,
  );

  Future<WalletTransactionRecord?> _lookupBitcoinTransaction({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) => _bitcoinProvider.loadRecordByTransactionHash(
    walletId: walletId,
    asset: asset,
    txHash: txHash,
  );

  Future<WalletTransactionRecord?> _lookupSuiTransaction({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) => _suiProvider.loadRecordByTransactionHash(
    walletId: walletId,
    asset: asset,
    txHash: txHash,
  );

  Future<WalletTransactionRecord?> _lookupAptosTransaction({
    required String walletId,
    required ChainBalance asset,
    required String txHash,
  }) => _aptosProvider.loadRecordByTransactionHash(
    walletId: walletId,
    asset: asset,
    txHash: txHash,
  );

  Future<TransactionHistoryPageResult> _loadTronRecordPage({
    required String walletId,
    required ChainBalance asset,
    required TransactionHistoryCursor? cursor,
  }) => _tronProvider.loadRecordPage(
    walletId: walletId,
    asset: asset,
    cursor: cursor,
  );

  Future<TransactionHistoryPageResult> _loadSolanaRecordPage({
    required String walletId,
    required ChainBalance asset,
    required TransactionHistoryCursor? cursor,
  }) => _solanaProvider.loadRecordPage(
    walletId: walletId,
    asset: asset,
    cursor: cursor,
  );

  Future<TransactionHistoryPageResult> _loadBitcoinRecordPage({
    required String walletId,
    required ChainBalance asset,
    required TransactionHistoryCursor? cursor,
  }) => _bitcoinProvider.loadRecordPage(
    walletId: walletId,
    asset: asset,
    cursor: cursor,
  );

  Future<TransactionHistoryPageResult> _loadSuiRecordPage({
    required String walletId,
    required ChainBalance asset,
    required TransactionHistoryCursor? cursor,
  }) => _suiProvider.loadRecordPage(
    walletId: walletId,
    asset: asset,
    cursor: cursor,
  );

  Future<TransactionHistoryPageResult> _loadAptosRecordPage({
    required String walletId,
    required ChainBalance asset,
    required TransactionHistoryCursor? cursor,
  }) => _aptosProvider.loadRecordPage(
    walletId: walletId,
    asset: asset,
    cursor: cursor,
  );

  Future<TransactionHistoryPageResult> _loadEvmRecordPage({
    required String walletId,
    required ChainBalance asset,
    required TransactionHistoryCursor? cursor,
  }) async {
    final chain = asset.chainRef;
    final canUseMoralisEvm =
        _moralisEvmProvider.supportsChain(chain) &&
        _apiConfig.hasMoralisApiKey &&
        (cursor == null || cursor.moralisCursor != null);
    if (canUseMoralisEvm) {
      try {
        SafeLog.error(
          'Using Moralis EVM history provider for ${chain.name} '
          'chainId=${chain.evmChainId}',
          name: 'WalletTransactionHistoryService',
        );
        final result = await _moralisEvmProvider.loadRecordPage(
          walletId: walletId,
          asset: asset,
          cursor: cursor,
        );
        if (result.records.isNotEmpty || cursor != null) return result;
      } catch (error) {
        if (error is TransactionHistoryLoadException &&
            (error.kind == TransactionHistoryFailureKind.rateLimited ||
                error.kind == TransactionHistoryFailureKind.apiKeyInvalid)) {
          rethrow;
        }
        SafeLog.error(
          'Moralis ${chain.name} history failed; '
          'falling back to EVM providers: $error',
          name: 'WalletTransactionHistoryService',
        );
      }
    }
    return _evmProvider.loadRecordPage(
      walletId: walletId,
      asset: asset,
      cursor: cursor,
    );
  }
}
