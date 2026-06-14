import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/wallet_transaction_record.dart';

/// 交易记录缓存服务。
///
/// 提供交易记录的本地缓存功能：
/// - 1小时过期时间
/// - 离线可查看历史记录
/// - 减少网络请求
class TransactionCache {
  static const String _cacheKeyPrefix = 'tx_cache_';
  static const String _timestampKeyPrefix = 'tx_timestamp_';
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// 保存交易记录到缓存。
  Future<void> cacheTransactions(
    String address,
    String chainId,
    List<WalletTransactionRecord> transactions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCacheKey(address, chainId);
    final timestampKey = _getTimestampKey(address, chainId);

    // 保存交易数据
    final data = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(key, jsonEncode(data));

    // 保存时间戳
    await prefs.setString(timestampKey, DateTime.now().toIso8601String());
  }

  /// 从缓存读取交易记录。
  ///
  /// 如果缓存不存在或已过期，返回 null。
  Future<List<WalletTransactionRecord>?> getCachedTransactions(
    String address,
    String chainId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getCacheKey(address, chainId);
    final timestampKey = _getTimestampKey(address, chainId);

    // 读取缓存数据
    final cached = prefs.getString(key);
    if (cached == null) return null;

    // 读取时间戳
    final timestampStr = prefs.getString(timestampKey);
    if (timestampStr == null) return null;

    // 检查是否过期
    final timestamp = DateTime.parse(timestampStr);
    final elapsed = DateTime.now().difference(timestamp);
    if (elapsed > _cacheExpiry) {
      // 过期，清除缓存
      await clearCache(address, chainId);
      return null;
    }

    // 解析数据
    try {
      final List<dynamic> data = jsonDecode(cached);
      return data
          .map((json) => WalletTransactionRecord.fromJson(json))
          .toList();
    } catch (e) {
      // 解析失败，清除缓存
      await clearCache(address, chainId);
      return null;
    }
  }

  /// 检查缓存是否存在且有效。
  Future<bool> hasCachedTransactions(
    String address,
    String chainId,
  ) async {
    final cached = await getCachedTransactions(address, chainId);
    return cached != null && cached.isNotEmpty;
  }

  /// 清除指定地址和链的缓存。
  Future<void> clearCache(String address, String chainId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCacheKey(address, chainId));
    await prefs.remove(_getTimestampKey(address, chainId));
  }

  /// 清除所有交易缓存。
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_timestampKeyPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// 获取缓存的剩余有效时间（秒）。
  Future<int> getRemainingSeconds(String address, String chainId) async {
    final prefs = await SharedPreferences.getInstance();
    final timestampKey = _getTimestampKey(address, chainId);
    final timestampStr = prefs.getString(timestampKey);

    if (timestampStr == null) return 0;

    final timestamp = DateTime.parse(timestampStr);
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = _cacheExpiry - elapsed;

    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  String _getCacheKey(String address, String chainId) {
    return '$_cacheKeyPrefix${chainId}_$address';
  }

  String _getTimestampKey(String address, String chainId) {
    return '$_timestampKeyPrefix${chainId}_$address';
  }
}
