import 'dart:developer' as developer;

/// 密码缓存服务。
///
/// 提供内存级密码缓存，用于生物识别成功后自动解锁。
/// 缓存仅保存在内存中，5分钟后自动过期。
class PasswordCacheService {
  /// 缓存的密码（仅内存存储）。
  static String? _cachedPassword;

  /// 缓存时间。
  static DateTime? _cacheTime;

  /// 缓存过期时间（5分钟）。
  static const _cacheExpiration = Duration(minutes: 5);

  /// 缓存密码。
  ///
  /// 密码仅保存在内存中，应用重启后消失。
  static void cachePassword(String password) {
    _cachedPassword = password;
    _cacheTime = DateTime.now();
    developer.log('Password cached, expires in 5 minutes');
  }

  /// 获取缓存的密码。
  ///
  /// 如果密码不存在或已过期，返回 null。
  static String? getCachedPassword() {
    if (_cachedPassword == null || _cacheTime == null) {
      return null;
    }

    // 检查是否过期
    final elapsed = DateTime.now().difference(_cacheTime!);
    if (elapsed > _cacheExpiration) {
      developer.log('Password cache expired');
      clearCache();
      return null;
    }

    final remaining = _cacheExpiration - elapsed;
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
  static bool hasCachedPassword() {
    return getCachedPassword() != null;
  }

  /// 获取缓存剩余时间（秒）。
  ///
  /// 如果没有缓存，返回 0。
  static int getRemainingSeconds() {
    if (_cachedPassword == null || _cacheTime == null) {
      return 0;
    }

    final elapsed = DateTime.now().difference(_cacheTime!);
    if (elapsed > _cacheExpiration) {
      return 0;
    }

    return (_cacheExpiration - elapsed).inSeconds;
  }
}
