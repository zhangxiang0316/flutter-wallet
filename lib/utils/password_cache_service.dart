import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// 密码缓存服务。
///
/// 提供内存级密码缓存，用于生物识别成功后自动解锁。
/// 缓存仅保存在内存中，过期时间可配置（1/5/10/30分钟）。
class PasswordCacheService {
  /// 按钱包隔离的内存缓存。
  ///
  /// key 为 walletId，避免多钱包使用不同密码时相互串用。
  static final Map<String, _CachedPassword> _cachedPasswords = {};

  /// SharedPreferences 键名。
  static const String _enabledKey = 'password_cache_enabled';
  static const String _expiryMinutesKey = 'password_cache_expiry_minutes';

  /// 默认过期时间（5分钟）。
  static const int _defaultExpiryMinutes = 5;

  /// 检查密码缓存是否启用。
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true; // 默认启用
  }

  /// 设置密码缓存开关。
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (!enabled) {
      // 禁用时清除缓存
      clearCache();
    }
    developer.log('Password cache ${enabled ? "enabled" : "disabled"}');
  }

  /// 获取缓存过期时间（分钟）。
  static Future<int> getExpiryMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_expiryMinutesKey) ?? _defaultExpiryMinutes;
  }

  /// 设置缓存过期时间（分钟）。
  static Future<void> setExpiryMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_expiryMinutesKey, minutes);
    developer.log('Password cache expiry set to $minutes minutes');
  }

  /// 缓存密码。
  ///
  /// 密码仅保存在内存中，应用重启后消失。
  static Future<void> cachePassword({
    required String walletId,
    required String password,
  }) async {
    final normalizedWalletId = walletId.trim();
    if (normalizedWalletId.isEmpty || password.isEmpty) {
      return;
    }
    final enabled = await isEnabled();
    if (!enabled) {
      developer.log('Password cache is disabled, not caching');
      return;
    }

    _cachedPasswords[normalizedWalletId] = _CachedPassword(
      password: password,
      cachedAt: DateTime.now(),
    );
    final expiryMinutes = await getExpiryMinutes();
    developer.log('Password cached, expires in $expiryMinutes minutes');
  }

  /// 获取缓存的密码。
  ///
  /// 如果密码不存在、已过期或功能被禁用，返回 null。
  static Future<String?> getCachedPassword(String walletId) async {
    final normalizedWalletId = walletId.trim();
    if (normalizedWalletId.isEmpty) {
      return null;
    }
    final enabled = await isEnabled();
    if (!enabled) {
      return null;
    }

    final cached = _cachedPasswords[normalizedWalletId];
    if (cached == null) {
      return null;
    }

    // 检查是否过期
    final expiryMinutes = await getExpiryMinutes();
    final elapsed = DateTime.now().difference(cached.cachedAt);
    if (elapsed > Duration(minutes: expiryMinutes)) {
      developer.log('Password cache expired');
      clearCache(walletId: normalizedWalletId);
      return null;
    }

    final remaining = Duration(minutes: expiryMinutes) - elapsed;
    developer.log('Password cache valid, expires in ${remaining.inSeconds}s');
    return cached.password;
  }

  /// 清除缓存的密码。
  static void clearCache({String? walletId}) {
    if (walletId == null) {
      _cachedPasswords.clear();
      developer.log('All password caches cleared');
      return;
    }
    final normalizedWalletId = walletId.trim();
    if (normalizedWalletId.isEmpty) return;
    _cachedPasswords.remove(normalizedWalletId);
    developer.log('Password cache cleared for wallet');
  }

  /// 检查是否有有效的缓存密码。
  static Future<bool> hasCachedPassword(String walletId) async {
    return await getCachedPassword(walletId) != null;
  }
}

class _CachedPassword {
  const _CachedPassword({required this.password, required this.cachedAt});

  final String password;
  final DateTime cachedAt;
}
