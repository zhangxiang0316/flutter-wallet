import 'package:dio/dio.dart';

import '../../../models/chain_balance.dart';
import '../../../models/wallet_transaction_record.dart';
import '../chain_transaction_provider.dart';
import '../transaction_cache.dart';

/// TRON 链交易记录提供者。
///
/// 使用 TronGrid API 获取交易记录。
/// API 文档：https://developers.tron.network/
class TronTransactionProvider implements ChainTransactionProvider {
  TronTransactionProvider({Dio? dio, TransactionCache? cache})
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

  static const String _apiUrl = 'https://api.trongrid.io';

  // TronGrid 官方免费 API，无需注册

  @override
  Future<List<WalletTransactionRecord>> loadRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final chainId = 'tron';
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

  /// 从 TronGrid API 获取交易记录。
  Future<List<WalletTransactionRecord>> _fetchFromApi(String address) async {
    try {
      // 获取 TRX 转账
      final trxTxs = await _fetchTrxTransactions(address);

      // 获取 TRC20 代币转账
      final tokenTxs = await _fetchTokenTransactions(address);

      // 合并并排序
      final allTxs = [...trxTxs, ...tokenTxs];
      allTxs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allTxs;
    } catch (error) {
      throw Exception('Failed to fetch TRON transactions: $error');
    }
  }

  /// 获取 TRX 转账记录。
  Future<List<WalletTransactionRecord>> _fetchTrxTransactions(
    String address,
  ) async {
    try {
      final response = await _dio.get(
        '$_apiUrl/v1/accounts/$address/transactions',
        queryParameters: {
          'limit': 50,
          'only_confirmed': true,
        },
      );

      final data = response.data;
      final List<dynamic> txs = data['data'] ?? [];

      return txs.map((tx) => _parseTransaction(tx)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取 TRC20 代币转账记录。
  Future<List<WalletTransactionRecord>> _fetchTokenTransactions(
    String address,
  ) async {
    try {
      final response = await _dio.get(
        '$_apiUrl/v1/accounts/$address/transactions/trc20',
        queryParameters: {
          'limit': 50,
          'only_confirmed': true,
        },
      );

      final data = response.data;
      final List<dynamic> txs = data['data'] ?? [];

      return txs.map((tx) => _parseTokenTransaction(tx)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 解析 TRX 交易。
  WalletTransactionRecord _parseTransaction(Map<String, dynamic> tx) {
    final rawData = tx['raw_data'] ?? {};
    final contract = (rawData['contract'] as List?)?.first ?? {};
    final value = contract['parameter']?['value'] ?? {};
    final timestamp = (tx['block_timestamp'] ?? 0) ~/ 1000;
    final hash = tx['txID'] ?? '';
    final from = value['owner_address'] ?? '';
    final to = value['to_address'] ?? '';

    return WalletTransactionRecord(
      id: hash,
      walletId: '',
      chainName: 'tron',
      symbol: 'TRX',
      assetName: 'TRON',
      walletAddress: from,
      txHash: hash,
      fromAddress: from,
      toAddress: to,
      amount: (value['amount'] ?? 0).toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      status: (tx['ret']?[0]?['contractRet'] ?? 'SUCCESS') == 'SUCCESS'
          ? 'success'
          : 'failed',
      fee: (tx['ret']?[0]?['fee'] ?? 0).toString(),
      blockNumber: tx['blockNumber'] ?? 0,
    );
  }

  /// 解析 TRC20 代币交易。
  WalletTransactionRecord _parseTokenTransaction(Map<String, dynamic> tx) {
    final timestamp = (tx['block_timestamp'] ?? 0) ~/ 1000;
    final hash = tx['transaction_id'] ?? '';
    final from = tx['from'] ?? '';
    final to = tx['to'] ?? '';

    return WalletTransactionRecord(
      id: hash,
      walletId: '',
      chainName: 'tron',
      symbol: tx['token_info']?['symbol'] ?? '',
      assetName: tx['token_info']?['name'] ?? '',
      walletAddress: from,
      txHash: hash,
      fromAddress: from,
      toAddress: to,
      amount: tx['value'] ?? '0',
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
      status: 'success',
      fee: '0',
      blockNumber: tx['block'] ?? 0,
      contractAddress: tx['token_info']?['address'],
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
        'tron',
        transactions,
      );
    } catch (e) {
      // 后台更新失败不影响用户体验
    }
  }
}
