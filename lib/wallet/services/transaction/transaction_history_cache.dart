import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chain_balance.dart';
import '../../models/wallet_transaction_record.dart';
import 'transaction_record_merger.dart';

/// 交易历史缓存服务。
///
/// 用于缓存交易记录，实现以下优化：
/// - 立即显示上次记录（< 50ms）
/// - 后台静默更新最新数据
/// - 减少 API 请求和失败率
class TransactionHistoryCache {
  /// 缓存键前缀。
  static const String _keyPrefix = 'tx_history_v1';

  static const String _localKeyPrefix = 'tx_local_v1';

  /// 缓存最大有效期。
  ///
  /// 交易历史 5 分钟内不会有太大变化，缓存可以有效减少请求。
  static const Duration _maxAge = Duration(minutes: 5);

  /// 本地提交记录的写入队列。
  ///
  /// 状态后台刷新和转账提交可能同时写缓存；串行化 read-modify-write，避免较旧
  /// 的 pending 快照在新 success/failed 状态之后落盘。
  Future<void> _localWriteTail = Future<void>.value();

  /// 生成缓存键。
  String _cacheKey(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) {
    final assetKey = _assetKey(contractAddress);
    return '${_keyPrefix}_${walletId}_${chainId}_${assetKey}_$symbol';
  }

  /// 旧版本缓存键，兼容升级前已保存的记录。
  String _legacyCacheKey(String walletId, String chainId, String symbol) {
    return '${_keyPrefix}_${walletId}_${chainId}_$symbol';
  }

  String _localCacheKey(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) {
    final assetKey = _assetKey(contractAddress);
    return '${_localKeyPrefix}_${walletId}_${chainId}_${assetKey}_$symbol';
  }

  String _assetKey(String? contractAddress) {
    final value = contractAddress?.trim();
    if (value == null || value.isEmpty) return 'native';
    return value.toLowerCase();
  }

  /// 加载指定资产的缓存交易记录。
  ///
  /// 返回 null 表示：
  /// - 缓存不存在
  /// - 缓存已过期且没有可用于离线兜底的记录
  /// - 缓存数据损坏
  Future<List<WalletTransactionRecord>?> load(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(
        walletId,
        chainId,
        symbol,
        contractAddress: contractAddress,
      );
      final candidates = <String?>[
        prefs.getString(key),
        prefs.getString(_legacyCacheKey(walletId, chainId, symbol)),
      ];
      List<WalletTransactionRecord>? freshEmptyRecords;
      for (final json in candidates) {
        if (json == null) continue;
        try {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final timestamp = DateTime.parse(data['timestamp'] as String);
          final records = (data['records'] as List)
              .map(
                (item) => WalletTransactionRecord.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList();

          // 非空历史即使过期也可先作为离线兜底，由调用方后台刷新。
          if (records.isNotEmpty) return records;
          if (DateTime.now().difference(timestamp) <= _maxAge) {
            freshEmptyRecords ??= records;
          }
        } catch (_) {
          // 当前格式损坏时继续尝试旧版本缓存。
        }
      }
      return freshEmptyRecords;
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
    List<WalletTransactionRecord> records, {
    String? contractAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(
        walletId,
        chainId,
        symbol,
        contractAddress: contractAddress,
      );
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // 保存失败不影响主流程，静默忽略
    }
  }

  /// 读取本地提交但可能尚未被链上历史接口索引到的交易。
  Future<List<WalletTransactionRecord>> loadLocalRecords(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _localCacheKey(
        walletId,
        chainId,
        symbol,
        contractAddress: contractAddress,
      );
      final json = prefs.getString(key);
      if (json == null) return const [];
      final data = jsonDecode(json) as Map<String, dynamic>;
      final records = (data['records'] as List)
          .map(
            (item) =>
                WalletTransactionRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      return records;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveLocalRecords(
    String walletId,
    String chainId,
    String symbol,
    List<WalletTransactionRecord> records, {
    String? contractAddress,
  }) {
    final previousWrite = _localWriteTail;
    final operation = () async {
      await previousWrite;
      await _mergeAndSaveLocalRecords(
        walletId,
        chainId,
        symbol,
        records,
        contractAddress: contractAddress,
      );
    }();
    _localWriteTail = operation;
    return operation;
  }

  Future<void> _mergeAndSaveLocalRecords(
    String walletId,
    String chainId,
    String symbol,
    List<WalletTransactionRecord> records, {
    String? contractAddress,
  }) async {
    try {
      final existing = await loadLocalRecords(
        walletId,
        chainId,
        symbol,
        contractAddress: contractAddress,
      );
      final safeRecords = const TransactionRecordMerger()
          .merge(existing, records)
          .where((record) => record.source == WalletTransactionSource.local)
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      final key = _localCacheKey(
        walletId,
        chainId,
        symbol,
        contractAddress: contractAddress,
      );
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'records': safeRecords.map((record) => record.toJson()).toList(),
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // 保存失败不影响转账主流程
    }
  }

  /// 追加或更新一条本地提交交易。
  Future<void> upsertLocalRecord(WalletTransactionRecord record) async {
    await saveLocalRecords(
      record.walletId,
      record.chainId,
      record.symbol,
      [record],
      contractAddress: record.contractAddress,
    );
  }

  /// 读取当前钱包在指定链上曾经使用过的收款地址。
  ///
  /// 同时合并链上历史缓存和本地待索引记录，并跨该链的原生币、Token 去重。失败、
  /// 入账和其它链的记录不会让一个地址被误判为“已使用”。
  Future<List<String>> loadChainRecipientAddresses({
    required String walletId,
    required String chainId,
    required Iterable<ChainBalance> assets,
  }) async {
    final uniqueAssets = <String, ChainBalance>{};
    for (final asset in assets) {
      if (asset.chainId != chainId) continue;
      final contract = asset.contractAddress?.trim();
      final key = [
        asset.symbol.toUpperCase(),
        contract == null || contract.isEmpty
            ? 'native'
            : contract.toLowerCase(),
      ].join(':');
      uniqueAssets[key] = asset;
    }

    final recordGroups = await Future.wait(
      uniqueAssets.values.map((asset) async {
        final remote =
            await load(
              walletId,
              chainId,
              asset.symbol,
              contractAddress: asset.contractAddress,
            ) ??
            const <WalletTransactionRecord>[];
        final local = await loadLocalRecords(
          walletId,
          chainId,
          asset.symbol,
          contractAddress: asset.contractAddress,
        );
        return [...remote, ...local];
      }),
    );

    final addresses = <String>{};
    for (final record in recordGroups.expand((records) => records)) {
      final isSent =
          record.direction == WalletTransactionDirection.outgoing ||
          record.direction == WalletTransactionDirection.selfTransfer;
      final address = record.toAddress.trim();
      if (record.chainId == chainId &&
          isSent &&
          record.status != WalletTransactionStatus.failed &&
          address.isNotEmpty) {
        addresses.add(address);
      }
    }
    return addresses.toList(growable: false);
  }

  /// 清除指定资产的交易记录缓存。
  ///
  /// 用于用户手动刷新或清理缓存时使用。
  Future<void> clear(
    String walletId,
    String chainId,
    String symbol, {
    String? contractAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(
        walletId,
        chainId,
        symbol,
        contractAddress: contractAddress,
      );
      await prefs.remove(key);
      await prefs.remove(_legacyCacheKey(walletId, chainId, symbol));
      await prefs.remove(
        _localCacheKey(
          walletId,
          chainId,
          symbol,
          contractAddress: contractAddress,
        ),
      );
    } catch (_) {
      // 清除失败不影响主流程
    }
  }
}
