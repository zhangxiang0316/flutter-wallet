import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';

/// 余额快照的数据来源。
enum BalanceSnapshotSource {
  /// 本次展示来自链上最新查询。
  network,

  /// 本次展示来自本地缓存。
  cache,

  /// 部分链为最新结果，失败链沿用上次成功缓存。
  mixed,
}

/// 余额快照对应的刷新状态。
enum BalanceRefreshStatus { idle, refreshing, success, partialFailure, failure }

/// 一组余额及其可信时间、来源和刷新状态。
class ChainBalanceSnapshot {
  const ChainBalanceSnapshot({
    required this.balances,
    required this.asOf,
    required this.source,
    required this.refreshStatus,
    this.isStale = false,
    this.error,
  });

  final List<ChainBalance> balances;
  final DateTime asOf;
  final BalanceSnapshotSource source;
  final BalanceRefreshStatus refreshStatus;
  final bool isStale;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  ChainBalanceSnapshot copyWith({
    List<ChainBalance>? balances,
    DateTime? asOf,
    BalanceSnapshotSource? source,
    BalanceRefreshStatus? refreshStatus,
    bool? isStale,
    String? error,
    bool clearError = false,
  }) {
    return ChainBalanceSnapshot(
      balances: balances ?? this.balances,
      asOf: asOf ?? this.asOf,
      source: source ?? this.source,
      refreshStatus: refreshStatus ?? this.refreshStatus,
      isStale: isStale ?? this.isStale,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// 链余额缓存服务。
///
/// 缓存仅保存余额快照和稳定链标识，不保存或重建 RPC 配置。读取时必须传入当前
/// 链注册表，所有余额都会重新绑定最新 [WalletChainConfig]；无法绑定的旧链资产
/// 会被忽略，避免占位 RPC 进入转账流程。
class ChainBalanceCache {
  ChainBalanceCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const String _keyPrefix = 'cached_balances_v3';
  static const String _legacyKeyPrefix = 'cached_balances_v2';

  /// 超过该时间的快照会被标记为旧数据。
  static const Duration maxAge = Duration(minutes: 30);

  final DateTime Function() _now;

  /// 加载指定钱包的缓存快照，并绑定当前启用链配置。
  ///
  /// 返回 null 表示缓存不存在、损坏、超过有效期且未允许旧数据，或快照中的
  /// 资产已经无法绑定任何当前启用链。首页可使用 [allowStale] 实现明确标识的
  /// stale-while-revalidate，转账等其它流程不应直接读取缓存。
  Future<ChainBalanceSnapshot?> load(
    String walletId, {
    required List<WalletChainConfig> chains,
    bool allowStale = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentJson = prefs.getString('${_keyPrefix}_$walletId');
      final legacyJson = prefs.getString('${_legacyKeyPrefix}_$walletId');
      final encoded = currentJson ?? legacyJson;
      if (encoded == null) return null;

      final data = jsonDecode(encoded) as Map<String, dynamic>;
      final asOf = _parseAsOf(data);
      if (asOf == null) return null;
      final isExpired = _now().difference(asOf) > maxAge;
      if (isExpired && !allowStale) return null;

      final balancesValue = data['balances'];
      if (balancesValue is! List) return null;
      final chainLookup = _ChainConfigLookup(chains);
      final balances = balancesValue
          .whereType<Map>()
          .map(
            (item) => _fromJson(Map<String, dynamic>.from(item), chainLookup),
          )
          .whereType<ChainBalance>()
          .toList(growable: false);
      if (balances.isEmpty) return null;

      final error = _optionalString(data['error']);
      return ChainBalanceSnapshot(
        balances: balances,
        asOf: asOf,
        source: BalanceSnapshotSource.cache,
        refreshStatus: _parseRefreshStatus(data['refreshStatus']),
        isStale: isExpired || data['isStale'] == true || error != null,
        error: error,
      );
    } catch (_) {
      return null;
    }
  }

  /// 保存余额快照。
  ///
  /// JSON 中只持久化稳定 chainId/evmChainId 和资产数值，不保存链名称、币种、
  /// RPC、浏览器或 API Key 等可执行配置。
  Future<void> save(String walletId, ChainBalanceSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'version': 3,
        'asOf': snapshot.asOf.toIso8601String(),
        'source': snapshot.source.name,
        'refreshStatus': snapshot.refreshStatus.name,
        'isStale': snapshot.isStale,
        'error': snapshot.error,
        'balances': snapshot.balances.map(_toJson).toList(growable: false),
      };
      await prefs.setString('${_keyPrefix}_$walletId', jsonEncode(data));
    } catch (_) {
      // 保存失败不影响主流程。
    }
  }

  /// 清除指定钱包的新旧余额缓存。
  Future<void> clear(String walletId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyPrefix}_$walletId');
      await prefs.remove('${_legacyKeyPrefix}_$walletId');
    } catch (_) {
      // 清除失败不影响主流程。
    }
  }

  Map<String, dynamic> _toJson(ChainBalance balance) {
    return {
      'chainId': balance.chainId,
      'evmChainId': balance.chainRef.evmChainId,
      'symbol': balance.symbol,
      'name': balance.name,
      'amount': balance.amount,
      'address': balance.address,
      'contractAddress': balance.contractAddress,
      'logoUrl': balance.logoUrl,
      'canonicalTokenId': balance.canonicalTokenId,
      'decimals': balance.decimals,
      'error': balance.error,
    };
  }

  ChainBalance? _fromJson(
    Map<String, dynamic> json,
    _ChainConfigLookup chains,
  ) {
    final chainId = json['chainId']?.toString() ?? '';
    final evmChainId = int.tryParse(json['evmChainId']?.toString() ?? '');
    final chainConfig = chains.find(chainId: chainId, evmChainId: evmChainId);
    if (chainConfig == null) return null;

    final symbol = json['symbol']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final amount = json['amount']?.toString() ?? '';
    final address = json['address']?.toString() ?? '';
    final decimals = json['decimals'];
    if (symbol.isEmpty || name.isEmpty || amount.isEmpty || address.isEmpty) {
      return null;
    }
    return ChainBalance.config(
      chainConfig: chainConfig,
      symbol: symbol,
      name: name,
      amount: amount,
      address: address,
      contractAddress: _optionalString(json['contractAddress']),
      logoUrl: _optionalString(json['logoUrl']),
      canonicalTokenId: _optionalString(json['canonicalTokenId']),
      decimals: decimals is int
          ? decimals
          : int.tryParse(decimals?.toString() ?? '') ?? 0,
      error: _optionalString(json['error']),
    );
  }

  DateTime? _parseAsOf(Map<String, dynamic> data) {
    final value = data['asOf'] ?? data['timestamp'];
    return DateTime.tryParse(value?.toString() ?? '');
  }

  BalanceRefreshStatus _parseRefreshStatus(Object? value) {
    final name = value?.toString();
    return BalanceRefreshStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => BalanceRefreshStatus.success,
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }
}

class _ChainConfigLookup {
  _ChainConfigLookup(List<WalletChainConfig> chains)
    : _byId = {for (final chain in chains) chain.id: chain},
      _byEvmChainId = {
        for (final chain in chains)
          if (chain.evmChainId != null) chain.evmChainId!: chain,
      };

  final Map<String, WalletChainConfig> _byId;
  final Map<int, WalletChainConfig> _byEvmChainId;

  WalletChainConfig? find({required String chainId, int? evmChainId}) {
    return _byId[chainId] ??
        (evmChainId == null ? null : _byEvmChainId[evmChainId]);
  }
}
