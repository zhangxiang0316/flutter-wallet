import 'package:dio/dio.dart';

import '../../../models/chain_balance.dart';
import '../../../models/wallet_transaction_record.dart';
import '../chain_transaction_provider.dart';
import '../transaction_cache.dart';

/// Solana 链交易记录提供者。
///
/// 使用 Solscan API 获取交易记录。
/// API 文档：https://pro-api.solscan.io/
class SolanaTransactionProvider implements ChainTransactionProvider {
  SolanaTransactionProvider({Dio? dio, TransactionCache? cache})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ),
        _cache = cache ?? TransactionCache();

  final Dio _dio;
  final TransactionCache _cache;

  static const String _apiUrl = 'https://api.solscan.io/account/transactions';

  // 免费 API，无需 Key（有限额）
  // 如需更高限额，注册：https://pro-api.solscan.io/

  @override
  Future<List<WalletTransactionRecord>> loadRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final chainId = 'solana';
    final address = asset.address;

    // 1. 尝试从缓存读取
    final cached = await _cache.getCachedTransactions(address, chainId);
    if (cached != null && cached.isNotEmpty) {
      // 后台更新
      _updateInBackground(walletId, asset);
      return cached;
    }

    // 2. 从 API 获取
    try {
      final transactions = await _fetchFromApi(address);

      // 3. 保存到缓存
      await _cache.cacheTransactions(address, chainId, transactions);

      return transactions;
    } catch (error) {
      // API 失败，返回缓存（即使过期）
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// 从 Solscan API 获取交易记录。
  Future<List<WalletTransactionRecord>> _fetchFromApi(String address) async {
    try {
      final response = await _dio.get(
        _apiUrl,
        queryParameters: {
          'address': address,
          'limit': 50, // 获取最近 50 笔交易
        },
      );

      final List<dynamic> data = response.data ?? [];
      return data.map((tx) => _parseTransaction(tx)).toList();
    } catch (error) {
      throw Exception('Failed to fetch Solana transactions: $error');
    }
  }

  /// 解析 Solana 交易。
  WalletTransactionRecord _parseTransaction(Map<String, dynamic> tx) {
    final timestamp = tx['blockTime'] ?? 0;
    final hash = tx['txHash'] ?? '';
    final from = tx['src'] ?? '';
    final to = tx['dst'] ?? '';

    return WalletTransactionRecord(
      id: hash,
      walletId: '',
      chainId: 'solana',
      chainName: 'solana',
      symbol: tx['tokenSymbol'] ?? 'SOL',
      assetName: tx['tokenName'] ?? 'Solana',
      walletAddress: from,
      txHash: hash,
      fromAddress: from,
      toAddress: to,
      amount: (tx['lamport'] ?? 0).toString(),
      decimals: tx['decimals'] ?? 9,
      direction: WalletTransactionDirection.unknown,
      status: (tx['status'] ?? 'Success') == 'Success'
          ? WalletTransactionStatus.success
          : WalletTransactionStatus.failed,
      source: WalletTransactionSource.remote,
      feeAmount: (tx['fee'] ?? 0).toString(),
      blockNumber: tx['slot'] ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      contractAddress: tx['tokenAddress'],
    );
  }

  /// 后台更新交易记录。
  Future<void> _updateInBackground(
    String walletId,
    ChainBalance asset,
  ) async {
    try {
      final transactions = await _fetchFromApi(asset.address);
      await _cache.cacheTransactions(
        asset.address,
        'solana',
        transactions,
      );
    } catch (e) {
      // 后台更新失败不影响用户体验
    }
  }
}
