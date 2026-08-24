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
import '../adapters/default_chain_adapter_registry.dart';
import '../constants/crypto_constants.dart';
import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_transaction_record.dart';
import '../utils/rpc_retry_helper.dart';
import '../../utils/safe_log.dart';
import 'wallet_history_api_config.dart';
import 'wallet_transfer_service.dart';

part 'transaction_history/transaction_history_provider_helpers.dart';
part 'transaction_history/transaction_history_models.dart';
part 'transaction_history/evm_history_provider_types.dart';
part 'transaction_history/evm_history_provider_routing.dart';
part 'transaction_history/evm_transaction_history_provider.dart';
part 'transaction_history/evm_explorer_history_client.dart';
part 'transaction_history/evm_rpc_history_provider.dart';
part 'transaction_history/evm_transaction_record_parsers.dart';
part 'transaction_history/moralis_evm_transaction_history_provider.dart';
part 'transaction_history/tron_transaction_history_provider.dart';
part 'transaction_history/solana_helius_history_helpers.dart';
part 'transaction_history/solana_helius_history_provider.dart';
part 'transaction_history/solana_transaction_history_provider.dart';
part 'transaction_history/solana_rpc_history_provider.dart';
part 'transaction_history/bitcoin_transaction_history_provider.dart';
part 'transaction_history/sui_transaction_history_provider.dart';
part 'transaction_history/aptos_transaction_history_provider.dart';

/// 钱包链上交易记录服务。
///
/// 对外保持统一入口；实际按链类型委托给 EVM、TRON、Solana Provider。
class WalletTransactionHistoryService {
  WalletTransactionHistoryService({
    Dio? dio,
    WalletHistoryApiConfig? apiConfig,
    ChainAdapterRegistry? adapterRegistry,
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
    _evmProvider = _EvmTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _moralisEvmProvider = _MoralisEvmTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _tronProvider = _TronTransactionHistoryProvider(
      dio: _dio,
      apiConfig: _apiConfig,
    );
    _solanaProvider = _SolanaTransactionHistoryProvider(
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
  }

  /// HTTP/RPC 请求客户端。
  final Dio _dio;

  final WalletHistoryApiConfig _apiConfig;
  final ChainAdapterRegistry _adapterRegistry;

  late final _EvmTransactionHistoryProvider _evmProvider;
  late final _MoralisEvmTransactionHistoryProvider _moralisEvmProvider;
  late final _TronTransactionHistoryProvider _tronProvider;
  late final _SolanaTransactionHistoryProvider _solanaProvider;
  late final _BitcoinTransactionHistoryProvider _bitcoinProvider;
  late final _SuiTransactionHistoryProvider _suiProvider;
  late final _AptosTransactionHistoryProvider _aptosProvider;

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
    return _adapterRegistry.route<Future<WalletTransactionRecord?>>(
      chain,
      capability: ChainCapability.history,
      handlers: <WalletChainType, Future<WalletTransactionRecord?> Function()>{
        WalletChainType.evm: () => _evmProvider.loadRecordByTransactionHash(
          walletId: walletId,
          asset: asset,
          txHash: txHash,
        ),
        WalletChainType.bitcoin: () =>
            _bitcoinProvider.loadRecordByTransactionHash(
              walletId: walletId,
              asset: asset,
              txHash: txHash,
            ),
        WalletChainType.sui: () => _suiProvider.loadRecordByTransactionHash(
          walletId: walletId,
          asset: asset,
          txHash: txHash,
        ),
        WalletChainType.aptos: () => _aptosProvider.loadRecordByTransactionHash(
          walletId: walletId,
          asset: asset,
          txHash: txHash,
        ),
      },
    );
  }

  /// 分页读取某个资产的链上交易记录。
  Future<TransactionHistoryPageResult> loadAssetRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final chain = asset.chainRef;
    return _adapterRegistry.route<Future<TransactionHistoryPageResult>>(
      chain,
      capability: ChainCapability.history,
      handlers:
          <WalletChainType, Future<TransactionHistoryPageResult> Function()>{
            WalletChainType.evm: () => _loadEvmRecordPage(
              walletId: walletId,
              asset: asset,
              cursor: cursor,
            ),
            WalletChainType.tron: () => _tronProvider.loadRecordPage(
              walletId: walletId,
              asset: asset,
              cursor: cursor,
            ),
            WalletChainType.solana: () => _solanaProvider.loadRecordPage(
              walletId: walletId,
              asset: asset,
              cursor: cursor,
            ),
            WalletChainType.bitcoin: () => _bitcoinProvider.loadRecordPage(
              walletId: walletId,
              asset: asset,
              cursor: cursor,
            ),
            WalletChainType.sui: () => _suiProvider.loadRecordPage(
              walletId: walletId,
              asset: asset,
              cursor: cursor,
            ),
            WalletChainType.aptos: () => _aptosProvider.loadRecordPage(
              walletId: walletId,
              asset: asset,
              cursor: cursor,
            ),
          },
    );
  }

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
