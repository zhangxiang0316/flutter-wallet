import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 封装。
///
/// 新代码优先使用类型化方法，例如 [getString]、[getJsonList]、[setJsonList]。
/// [getStorage]、[setStorage] 保留给旧调用方做兼容迁移。
class Storage {
  static final Storage _instance = Storage._();

  factory Storage() => _instance;

  Storage._();

  Future<SharedPreferences> get _preferences {
    return SharedPreferences.getInstance();
  }

  /// 兼容旧入口：保存基础类型；Map/List 会按 JSON 字符串保存。
  ///
  /// 不支持的类型保持旧实现的宽松行为：忽略写入。
  Future<void> setStorage(String key, dynamic value) async {
    final prefs = await _preferences;
    if (value is Map || value is List) {
      await prefs.setString(key, jsonEncode(value));
      return;
    }
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  /// 兼容旧入口：key 不存在时返回空字符串；JSON 字符串会自动解码。
  Future<dynamic> getStorage(String key) async {
    final value = await getValue(key);
    if (value == null) {
      return '';
    }
    return _decodeJsonString(value) ?? value;
  }

  /// 读取原始 SharedPreferences 值，不做 JSON 自动解码。
  Future<Object?> getValue(String key) async {
    final prefs = await _preferences;
    return prefs.get(key);
  }

  Future<String?> getString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  Future<List<dynamic>?> getJsonList(String key) async {
    final value = await getValue(key);
    if (value is List) {
      return List<dynamic>.from(value);
    }
    final decoded = _decodeJsonString(value);
    if (decoded is List) {
      return decoded;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getJsonMap(String key) async {
    final decoded = _decodeJsonString(await getValue(key));
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Future<void> setString(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  Future<void> setJsonList(String key, List<dynamic> value) async {
    final prefs = await _preferences;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<void> setJsonMap(String key, Map<String, dynamic> value) async {
    final prefs = await _preferences;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<bool> remove(String key) async {
    final prefs = await _preferences;
    return prefs.remove(key);
  }

  dynamic _decodeJsonString(Object? value) {
    if (value is! String) {
      return null;
    }
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
}
