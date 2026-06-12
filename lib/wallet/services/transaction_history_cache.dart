import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_transaction_record.dart';

/// 交易历史缓存服务。
///
/// 用于缓存交易记录，实现以下优化：
/// - 立即显示上次记录（< 50ms）
/// - 后台静默更新最新数据
/// - 减少 API 请求和失败率
class TransactionHistoryCache {
  /// 缓存键前缀。
  static const String _keyPrefix = 'tx_history_v1';

  /// 缓存最大有效期。
  ///
  /// 交易历史 5 分钟内不会有太大变化，缓存可以有效减少请求。
  static const Duration _maxAge = Duration(minutes: 5);

  /// 生成缓存键。
  String _cacheKey(String walletId, String chainId, String symbol) {
    return '${_keyPrefix}_${walletId}_${chainId}_$symbol';
  }

  /// 加载指定资产的缓存交易记录。
  ///
  /// 返回 null 表示：
  /// - 缓存不存在
  /// - 缓存已过期（超过 5 分钟）
  /// - 缓存数据损坏
  Future<List<WalletTransactionRecord>?> load(
    String walletId,
    String chainId,
    String symbol,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(walletId, chainId, symbol);
      final json = prefs.getString(key);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);

      // 检查缓存是否过期
      if (DateTime.now().difference(timestamp) > _maxAge) {
        return null;
      }

      final records = (data['records'] as List)
          .map((item) => WalletTransactionRecord.fromJson(item as Map<String, dynamic>))
          .toList();

      return records;
    } catch (_) {
      // 缓存损坏，返回 null
      return null;
    }
  }

  /// 保存指定资产的交易记录缓存。
  ///
  /// 会自动添加时间戳，用于判断缓存是否过期。
  Future<void> save(
    String walletId,
    String chainId,
    String symbol,
    List<WalletTransactionRecord> records,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(walletId, chainId, symbol);
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // 保存失败不影响主流程，静默忽略
    }
  }

  /// 清除指定资产的交易记录缓存。
  ///
  /// 用于用户手动刷新或清理缓存时使用。
  Future<void> clear(String walletId, String chainId, String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(walletId, chainId, symbol);
      await prefs.remove(key);
    } catch (_) {
      // 清除失败不影响主流程
    }
  }

  /// 清除所有交易记录缓存。
  ///
  /// 用于强制刷新或重置应用时使用。
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_keyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {
      // 清除失败不影响主流程
    }
  }
}
