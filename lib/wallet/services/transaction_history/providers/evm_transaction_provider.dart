import 'package:dio/dio.dart';

import '../../../models/chain_balance.dart';
import '../../../models/wallet_transaction_record.dart';
import '../chain_transaction_provider.dart';
import '../transaction_cache.dart';

/// EVM 链交易记录提供者。
///
/// 使用 Etherscan 兼容的 API 获取交易记录。
/// 支持的链：Ethereum, BSC, Polygon, Arbitrum, Optimism 等。
class EvmTransactionProvider implements ChainTransactionProvider {
  EvmTransactionProvider({Dio? dio, TransactionCache? cache})
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

  // Etherscan 兼容 API 端点
  static const Map<String, String> _apiEndpoints = {
    'ethereum': 'https://api.etherscan.io/api',
    'bsc': 'https://api.bscscan.com/api',
    'polygon': 'https://api.polygonscan.com/api',
    'arbitrum': 'https://api.arbiscan.io/api',
    'optimism': 'https://api-optimistic.etherscan.io/api',
    'base': 'https://api.basescan.org/api',
  };

  // 注意：这些是示例 API Key，生产环境需要注册并使用自己的 Key
  // 注册地址：https://etherscan.io/apis
  static const Map<String, String> _apiKeys = {
    'ethereum': 'YourApiKeyToken', // 免费注册
    'bsc': 'YourApiKeyToken',
    'polygon': 'YourApiKeyToken',
    'arbitrum': 'YourApiKeyToken',
    'optimism': 'YourApiKeyToken',
    'base': 'YourApiKeyToken',
  };

  @override
  Future<List<WalletTransactionRecord>> loadRecords({
    required String walletId,
    required ChainBalance asset,
  }) async {
    final chainId = asset.chainRef.id;
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
      final transactions = await _fetchFromApi(address, chainId);

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

  /// 从 Etherscan API 获取交易记录。
  Future<List<WalletTransactionRecord>> _fetchFromApi(
    String address,
    String chainId,
  ) async {
    final apiUrl = _apiEndpoints[chainId];
    final apiKey = _apiKeys[chainId] ?? '';

    if (apiUrl == null) {
      throw Exception('Unsupported chain: $chainId');
    }

    try {
      // 获取普通交易
      final normalTxs = await _fetchNormalTransactions(
        apiUrl,
        apiKey,
        address,
        chainId,
      );

      // 获取内部交易（合约调用）
      final internalTxs = await _fetchInternalTransactions(
        apiUrl,
        apiKey,
        address,
        chainId,
      );

      // 获取 ERC20 代币转账
      final tokenTxs = await _fetchTokenTransactions(
        apiUrl,
        apiKey,
        address,
        chainId,
      );

      // 合并并排序
      final allTxs = [...normalTxs, ...internalTxs, ...tokenTxs];
      allTxs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return allTxs;
    } catch (error) {
      throw Exception('Failed to fetch transactions: $error');
    }
  }

  /// 获取普通交易。
  Future<List<WalletTransactionRecord>> _fetchNormalTransactions(
    String apiUrl,
    String apiKey,
    String address,
    String chainId,
  ) async {
    final url = '$apiUrl?module=account&action=txlist'
        '&address=$address&sort=desc&apikey=$apiKey';

    final response = await _dio.get(url);
    final data = response.data;

    if (data['status'] != '1') {
      return [];
    }

    final List<dynamic> result = data['result'] ?? [];
    return result.map((tx) => _parseTransaction(tx, chainId)).toList();
  }

  /// 获取内部交易。
  Future<List<WalletTransactionRecord>> _fetchInternalTransactions(
    String apiUrl,
    String apiKey,
    String address,
    String chainId,
  ) async {
    final url = '$apiUrl?module=account&action=txlistinternal'
        '&address=$address&sort=desc&apikey=$apiKey';

    try {
      final response = await _dio.get(url);
      final data = response.data;

      if (data['status'] != '1') {
        return [];
      }

      final List<dynamic> result = data['result'] ?? [];
      return result.map((tx) => _parseTransaction(tx, chainId)).toList();
    } catch (e) {
      // 内部交易失败不影响其他交易
      return [];
    }
  }

  /// 获取 ERC20 代币交易。
  Future<List<WalletTransactionRecord>> _fetchTokenTransactions(
    String apiUrl,
    String apiKey,
    String address,
    String chainId,
  ) async {
    final url = '$apiUrl?module=account&action=tokentx'
        '&address=$address&sort=desc&apikey=$apiKey';

    try {
      final response = await _dio.get(url);
      final data = response.data;

      if (data['status'] != '1') {
        return [];
      }

      final List<dynamic> result = data['result'] ?? [];
      return result.map((tx) => _parseTokenTransaction(tx, chainId)).toList();
    } catch (e) {
      // 代币交易失败不影响其他交易
      return [];
    }
  }

  /// 解析普通交易。
  WalletTransactionRecord _parseTransaction(
    Map<String, dynamic> tx,
    String chainId,
  ) {
    return WalletTransactionRecord(
      hash: tx['hash'] ?? '',
      from: tx['from'] ?? '',
      to: tx['to'] ?? '',
      value: tx['value'] ?? '0',
      timestamp: int.parse(tx['timeStamp'] ?? '0'),
      blockNumber: int.parse(tx['blockNumber'] ?? '0'),
      gasUsed: tx['gasUsed'] ?? '0',
      gasPrice: tx['gasPrice'] ?? '0',
      isError: (tx['isError'] ?? '0') == '1',
      chainId: chainId,
    );
  }

  /// 解析代币交易。
  WalletTransactionRecord _parseTokenTransaction(
    Map<String, dynamic> tx,
    String chainId,
  ) {
    return WalletTransactionRecord(
      hash: tx['hash'] ?? '',
      from: tx['from'] ?? '',
      to: tx['to'] ?? '',
      value: tx['value'] ?? '0',
      timestamp: int.parse(tx['timeStamp'] ?? '0'),
      blockNumber: int.parse(tx['blockNumber'] ?? '0'),
      gasUsed: tx['gasUsed'] ?? '0',
      gasPrice: tx['gasPrice'] ?? '0',
      isError: false,
      chainId: chainId,
      tokenSymbol: tx['tokenSymbol'],
      tokenName: tx['tokenName'],
      tokenDecimal: int.tryParse(tx['tokenDecimal'] ?? '18'),
      contractAddress: tx['contractAddress'],
    );
  }

  /// 后台更新交易记录。
  Future<void> _updateInBackground(
    String walletId,
    ChainBalance asset,
  ) async {
    try {
      final transactions = await _fetchFromApi(
        asset.address,
        asset.chainRef.id,
      );
      await _cache.cacheTransactions(
        asset.address,
        asset.chainRef.id,
        transactions,
      );
    } catch (e) {
      // 后台更新失败不影响用户体验
    }
  }
}
