import 'package:dio/dio.dart';

import '../../models/chain_balance.dart';
import '../../models/wallet_transaction_record.dart';
import 'chain_transaction_provider.dart';
import 'providers/evm_transaction_provider.dart';
import 'providers/solana_transaction_provider.dart';
import 'providers/tron_transaction_provider.dart';
import 'transaction_cache.dart';

/// 钱包交易历史服务。
///
/// 使用 Provider 模式，根据不同链类型委托给相应的 Provider 处理。
/// 支持本地缓存和后台更新。
class TransactionHistoryService {
  TransactionHistoryService({
    Dio? dio,
    TransactionCache? cache,
    EvmTransactionProvider? evmProvider,
    TronTransactionProvider? tronProvider,
    SolanaTransactionProvider? solanaProvider,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 10),
              ),
            ),
        _cache = cache ?? TransactionCache(),
        _evmProvider = evmProvider ?? EvmTransactionProvider(dio: dio, cache: cache),
        _tronProvider = tronProvider ?? TronTransactionProvider(dio: dio, cache: cache),
        _solanaProvider =
            solanaProvider ?? SolanaTransactionProvider(dio: dio, cache: cache);

  final Dio _dio;
  final TransactionCache _cache;
  final EvmTransactionProvider _evmProvider;
  final TronTransactionProvider _tronProvider;
  final SolanaTransactionProvider _solanaProvider;

  /// 加载指定资产的交易记录。
  ///
  /// 根据资产所属的链类型，委托给相应的 Provider 处理。
  Future<List<WalletTransactionRecord>> loadAssetRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final chain = asset.chainRef;

    if (chain.isEvm) {
      return _evmProvider.loadRecords(walletId: walletId, asset: asset);
    }

    if (chain.id == 'tron') {
      return _tronProvider.loadRecords(walletId: walletId, asset: asset);
    }

    if (chain.id == 'solana') {
      return _solanaProvider.loadRecords(walletId: walletId, asset: asset);
    }

    // 未知链返回空列表
    return const [];
  }

  /// 清理资源
  void dispose() {
    // 如果需要的话，可以在这里清理 provider 资源
  }

  /// 清除所有交易缓存。
  Future<void> clearAllCache() async {
    await _cache.clearAllCache();
  }

  /// 清除指定地址的缓存。
  Future<void> clearCache(String address, String chainId) async {
    await _cache.clearCache(address, chainId);
  }

  /// 检查是否有缓存。
  Future<bool> hasCachedTransactions(String address, String chainId) async {
    return await _cache.hasCachedTransactions(address, chainId);
  }
}
