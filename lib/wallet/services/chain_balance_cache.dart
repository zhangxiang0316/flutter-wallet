import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chain_balance.dart';
import '../models/wallet_chain.dart';

/// 链余额缓存服务。
///
/// 用于缓存用户的余额数据，实现以下优化：
/// - 打开首页立即显示上次余额（< 50ms）
/// - 后台静默更新最新数据
/// - 离线时也能查看上次余额
class ChainBalanceCache {
  /// 缓存键前缀。
  static const String _keyPrefix = 'cached_balances_v2';

  /// 缓存最大有效期。
  ///
  /// 超过 30 分钟的缓存视为过期，返回 null 强制重新加载。
  static const Duration _maxAge = Duration(minutes: 30);

  /// 加载指定钱包的缓存余额。
  ///
  /// 返回 null 表示：
  /// - 缓存不存在
  /// - 缓存已过期且 [allowStale] 为 false
  /// - 缓存数据损坏
  ///
  /// 首页传入 [allowStale] 后会先展示最后一次成功余额，再在后台刷新链上数据。
  /// 这样即使用户较长时间没有打开应用，也不会退回整页骨架屏。
  Future<List<ChainBalance>?> load(
    String walletId, {
    bool allowStale = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('${_keyPrefix}_$walletId');
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      final timestamp = DateTime.parse(data['timestamp'] as String);

      // 普通调用仍遵循有效期；首页可显式启用 stale-while-revalidate。
      if (!allowStale && DateTime.now().difference(timestamp) > _maxAge) {
        return null;
      }

      final balances = (data['balances'] as List)
          .map((item) => _fromJson(item as Map<String, dynamic>))
          .toList();

      return balances;
    } catch (_) {
      // 缓存损坏，返回 null
      return null;
    }
  }

  /// 保存指定钱包的余额缓存。
  ///
  /// 会自动添加时间戳，用于判断缓存是否过期。
  Future<void> save(String walletId, List<ChainBalance> balances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'balances': balances.map((b) => _toJson(b)).toList(),
      };
      await prefs.setString('${_keyPrefix}_$walletId', jsonEncode(data));
    } catch (_) {
      // 保存失败不影响主流程，静默忽略
    }
  }

  /// 清除指定钱包的余额缓存。
  ///
  /// 用于钱包切换或删除时清理缓存。
  Future<void> clear(String walletId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyPrefix}_$walletId');
    } catch (_) {
      // 清除失败不影响主流程
    }
  }

  /// 将 ChainBalance 转换为 JSON。
  Map<String, dynamic> _toJson(ChainBalance balance) {
    return {
      'chainId': balance.chainId,
      'chainName': balance.chainRef.name,
      'chainSymbol': balance.chainRef.symbol,
      'evmChainId': balance.chainRef.evmChainId,
      'symbol': balance.symbol,
      'name': balance.name,
      'amount': balance.amount,
      'address': balance.address,
      'contractAddress': balance.contractAddress,
      'logoUrl': balance.logoUrl,
      'canonicalTokenId': balance.canonicalTokenId,
      'decimals': balance.decimals,
      'isNative': balance.isNative,
      'error': balance.error,
    };
  }

  /// 从 JSON 恢复 ChainBalance。
  ChainBalance _fromJson(Map<String, dynamic> json) {
    final chainId = json['chainId'] as String;

    // 尝试匹配内置链
    WalletChain? chain;
    try {
      chain = WalletChain.values.firstWhere((c) => c.id == chainId);
    } catch (_) {
      // 如果不是内置链，chain 为 null
    }

    if (chain != null) {
      return ChainBalance(
        chain: chain,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        amount: json['amount'] as String,
        address: json['address'] as String,
        contractAddress: json['contractAddress'] as String?,
        logoUrl: json['logoUrl'] as String?,
        canonicalTokenId: json['canonicalTokenId'] as String?,
        decimals: json['decimals'] as int,
        error: json['error'] as String?,
      );
    }

    final evmChainId = int.tryParse(json['evmChainId']?.toString() ?? '');
    if (evmChainId == WalletChain.polygon.evmChainId) {
      return ChainBalance(
        chain: WalletChain.polygon,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        amount: json['amount'] as String,
        address: json['address'] as String,
        contractAddress: json['contractAddress'] as String?,
        logoUrl: json['logoUrl'] as String?,
        canonicalTokenId: json['canonicalTokenId'] as String?,
        decimals: json['decimals'] as int,
        error: json['error'] as String?,
      );
    }
    if (evmChainId == WalletChain.avalanche.evmChainId) {
      return ChainBalance(
        chain: WalletChain.avalanche,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        amount: json['amount'] as String,
        address: json['address'] as String,
        contractAddress: json['contractAddress'] as String?,
        logoUrl: json['logoUrl'] as String?,
        canonicalTokenId: json['canonicalTokenId'] as String?,
        decimals: json['decimals'] as int,
        error: json['error'] as String?,
      );
    }
    if (evmChainId != null) {
      final chainConfig = WalletChainConfig.customEvm(
        id: chainId,
        name: json['chainName'] as String? ?? chainId,
        symbol: json['chainSymbol'] as String? ?? '',
        rpcUrls: const ['http://localhost'],
        evmChainId: evmChainId,
      );
      return ChainBalance.config(
        chainConfig: chainConfig,
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        amount: json['amount'] as String,
        address: json['address'] as String,
        contractAddress: json['contractAddress'] as String?,
        logoUrl: json['logoUrl'] as String?,
        canonicalTokenId: json['canonicalTokenId'] as String?,
        decimals: json['decimals'] as int,
        error: json['error'] as String?,
      );
    }

    // 无法识别的旧缓存不参与估值，等待本轮链上查询覆盖。
    return ChainBalance(
      chain: WalletChain.bsc,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      amount: '0',
      address: json['address'] as String,
      contractAddress: json['contractAddress'] as String?,
      logoUrl: json['logoUrl'] as String?,
      canonicalTokenId: json['canonicalTokenId'] as String?,
      decimals: json['decimals'] as int,
      error: 'Unsupported cached chain',
    );
  }
}
