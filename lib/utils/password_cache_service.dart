import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// 密码缓存服务。
///
/// 提供内存级密码缓存，用于生物识别成功后自动解锁。
/// 缓存仅保存在内存中，过期时间可配置（1/5/10/30分钟）。
class PasswordCacheService {
  /// 缓存的密码（仅内存存储）。
  static String? _cachedPassword;

  /// 缓存时间。
  static DateTime? _cacheTime;

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
  static Future<void> cachePassword(String password) async {
    final enabled = await isEnabled();
    if (!enabled) {
      developer.log('Password cache is disabled, not caching');
      return;
    }

    _cachedPassword = password;
    _cacheTime = DateTime.now();
    final expiryMinutes = await getExpiryMinutes();
    developer.log('Password cached, expires in $expiryMinutes minutes');
  }

  /// 获取缓存的密码。
  ///
  /// 如果密码不存在、已过期或功能被禁用，返回 null。
  static Future<String?> getCachedPassword() async {
    final enabled = await isEnabled();
    if (!enabled) {
      return null;
    }

    if (_cachedPassword == null || _cacheTime == null) {
      return null;
    }

    // 检查是否过期
    final expiryMinutes = await getExpiryMinutes();
    final elapsed = DateTime.now().difference(_cacheTime!);
    if (elapsed > Duration(minutes: expiryMinutes)) {
      developer.log('Password cache expired');
      clearCache();
      return null;
    }

    final remaining = Duration(minutes: expiryMinutes) - elapsed;
    developer.log('Password cache valid, expires in ${remaining.inSeconds}s');
    return _cachedPassword;
  }

  /// 清除缓存的密码。
  static void clearCache() {
    _cachedPassword = null;
    _cacheTime = null;
    developer.log('Password cache cleared');
  }

  /// 检查是否有有效的缓存密码。
  static Future<bool> hasCachedPassword() async {
    return await getCachedPassword() != null;
  }

  /// 获取缓存剩余时间（秒）。
  ///
  /// 如果没有缓存或已禁用，返回 0。
  static Future<int> getRemainingSeconds() async {
    final enabled = await isEnabled();
    if (!enabled || _cachedPassword == null || _cacheTime == null) {
      return 0;
    }

    final expiryMinutes = await getExpiryMinutes();
    final elapsed = DateTime.now().difference(_cacheTime!);
    final expiry = Duration(minutes: expiryMinutes);

    if (elapsed > expiry) {
      return 0;
    }

    return (expiry - elapsed).inSeconds;
  }
}
