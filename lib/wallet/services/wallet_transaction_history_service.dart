import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:sui/sui.dart';

import '../constants/crypto_constants.dart';
import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';
import '../models/wallet_transaction_record.dart';
import '../utils/rpc_retry_helper.dart';
import 'wallet_history_api_config.dart';
import 'wallet_transfer_service.dart';

part 'transaction_history/transaction_history_provider_helpers.dart';
part 'transaction_history/evm_history_provider_types.dart';
part 'transaction_history/evm_history_provider_routing.dart';
part 'transaction_history/evm_transaction_history_provider.dart';
part 'transaction_history/evm_transaction_record_parsers.dart';
part 'transaction_history/moralis_evm_transaction_history_provider.dart';
part 'transaction_history/tron_transaction_history_provider.dart';
part 'transaction_history/solana_helius_history_helpers.dart';
part 'transaction_history/solana_transaction_history_provider.dart';
part 'transaction_history/bitcoin_transaction_history_provider.dart';
part 'transaction_history/sui_transaction_history_provider.dart';
part 'transaction_history/aptos_transaction_history_provider.dart';

const int _transactionHistoryPageSize = 10;

enum TransactionHistoryFailureKind {
  noRecords,
  rateLimited,
  apiKeyMissing,
  apiKeyInvalid,
  timeout,
  providerFailed,
}

class TransactionHistoryLoadException implements Exception {
  const TransactionHistoryLoadException(this.kind, this.message, [this.cause]);

  final TransactionHistoryFailureKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// 交易历史分页游标。
class TransactionHistoryCursor {
  const TransactionHistoryCursor._(this.source, this.value);

  const TransactionHistoryCursor.evmExplorerPage(int page)
    : this._('evmExplorerPage', page);

  const TransactionHistoryCursor.evmLogBeforeBlock(int block)
    : this._('evmLogBeforeBlock', block);

  const TransactionHistoryCursor.blockscoutPage(String value)
    : this._('blockscoutPage', value);

  const TransactionHistoryCursor.moralisCursor(String value)
    : this._('moralisCursor', value);

  const TransactionHistoryCursor.tronFingerprint(String value)
    : this._('tronFingerprint', value);

  const TransactionHistoryCursor.solanaBefore(String value)
    : this._('solanaBefore', value);

  const TransactionHistoryCursor.bitcoinLastSeenTxId(String value)
    : this._('bitcoinLastSeenTxId', value);

  const TransactionHistoryCursor.suiGraphqlCursor(String value)
    : this._('suiGraphqlCursor', value);

  const TransactionHistoryCursor.aptosOffset(int value)
    : this._('aptosOffset', value);

  /// 游标来源。
  final String source;

  /// 来源特定的下一页参数。
  final Object value;

  int? get evmPage => source == 'evmExplorerPage' ? value as int : null;

  int? get evmLogBeforeBlock =>
      source == 'evmLogBeforeBlock' ? value as int : null;

  String? get blockscoutParams =>
      source == 'blockscoutPage' ? value as String : null;

  String? get moralisCursor =>
      source == 'moralisCursor' ? value as String : null;

  String? get tronFingerprint =>
      source == 'tronFingerprint' ? value as String : null;

  String? get solanaBefore => source == 'solanaBefore' ? value as String : null;

  String? get bitcoinLastSeenTxId =>
      source == 'bitcoinLastSeenTxId' ? value as String : null;

  String? get suiGraphqlCursor =>
      source == 'suiGraphqlCursor' ? value as String : null;

  int? get aptosOffset => source == 'aptosOffset' ? value as int : null;
}

/// 交易历史分页结果。
class TransactionHistoryPageResult {
  const TransactionHistoryPageResult({
    required this.records,
    required this.nextCursor,
    this.emptyReason,
  });

  /// 当前页交易记录。
  final List<WalletTransactionRecord> records;

  /// 下一页游标；为 null 表示当前数据源没有更多可取记录。
  final TransactionHistoryCursor? nextCursor;

  /// 空列表原因；仅在成功请求但没有记录时使用。
  final TransactionHistoryFailureKind? emptyReason;

  bool get hasMore => nextCursor != null;
}

/// 钱包链上交易记录服务。
///
/// 对外保持统一入口；实际按链类型委托给 EVM、TRON、Solana Provider。
class WalletTransactionHistoryService {
  WalletTransactionHistoryService({Dio? dio, WalletHistoryApiConfig? apiConfig})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: _requestTimeout,
              receiveTimeout: _requestTimeout,
              sendTimeout: _requestTimeout,
            ),
          ),
      _apiConfig = apiConfig ?? const WalletHistoryApiConfig() {
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
    if (chain.isEvm) {
      return _evmProvider.loadRecordByTransactionHash(
        walletId: walletId,
        asset: asset,
        txHash: txHash,
      );
    }
    if (_isBitcoinChain(chain)) {
      return _bitcoinProvider.loadRecordByTransactionHash(
        walletId: walletId,
        asset: asset,
        txHash: txHash,
      );
    }
    if (_isSuiChain(chain)) {
      return _suiProvider.loadRecordByTransactionHash(
        walletId: walletId,
        asset: asset,
        txHash: txHash,
      );
    }
    if (_isAptosChain(chain)) {
      return _aptosProvider.loadRecordByTransactionHash(
        walletId: walletId,
        asset: asset,
        txHash: txHash,
      );
    }
    return null;
  }

  /// 分页读取某个资产的链上交易记录。
  Future<TransactionHistoryPageResult> loadAssetRecordPage({
    required String walletId,
    required ChainBalance asset,
    TransactionHistoryCursor? cursor,
  }) async {
    final chain = asset.chainRef;
    if (chain.isEvm) {
      final canUseMoralisEvm =
          _moralisEvmProvider.supportsChain(chain) &&
          _apiConfig.hasMoralisApiKey &&
          (cursor == null || cursor.moralisCursor != null);
      if (canUseMoralisEvm) {
        try {
          developer.log(
            'Using Moralis EVM history provider for ${chain.name} '
            'chainId=${chain.evmChainId}',
            name: 'WalletTransactionHistoryService',
          );
          final result = await _moralisEvmProvider.loadRecordPage(
            walletId: walletId,
            asset: asset,
            cursor: cursor,
          );
          if (result.records.isNotEmpty || cursor != null) {
            return result;
          }
        } catch (error) {
          if (error is TransactionHistoryLoadException &&
              (error.kind == TransactionHistoryFailureKind.rateLimited ||
                  error.kind == TransactionHistoryFailureKind.apiKeyInvalid)) {
            rethrow;
          }
          developer.log(
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
    if (_isTronChain(chain)) {
      return _tronProvider.loadRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (_isSolanaChain(chain)) {
      return _solanaProvider.loadRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (_isBitcoinChain(chain)) {
      return _bitcoinProvider.loadRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (_isSuiChain(chain)) {
      return _suiProvider.loadRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    if (_isAptosChain(chain)) {
      return _aptosProvider.loadRecordPage(
        walletId: walletId,
        asset: asset,
        cursor: cursor,
      );
    }
    return const TransactionHistoryPageResult(
      records: [],
      nextCursor: null,
      emptyReason: TransactionHistoryFailureKind.noRecords,
    );
  }

  bool _isTronChain(WalletChainRef chain) {
    return chain.id == WalletChain.tron.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.tron);
  }

  bool _isSolanaChain(WalletChainRef chain) {
    return chain.id == WalletChain.solana.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.solana);
  }

  bool _isBitcoinChain(WalletChainRef chain) {
    return chain.id == WalletChain.bitcoin.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.bitcoin);
  }

  bool _isSuiChain(WalletChainRef chain) {
    return chain.id == WalletChain.sui.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.sui);
  }

  bool _isAptosChain(WalletChainRef chain) {
    return chain.id == WalletChain.aptos.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.aptos);
  }
}
