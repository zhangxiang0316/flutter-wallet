import 'dart:async';

import 'package:flutter/foundation.dart';

import 'screen_security_state.dart';
import 'screen_security_platform_stub.dart'
    if (dart.library.io) 'screen_security_platform_io.dart'
    as platform;

export 'screen_security_state.dart';

typedef ScreenSecurityOperation =
    Future<ScreenSecurityState> Function(bool enabled);

/// 一个敏感页面持有的屏幕保护租约。
///
/// 页面必须在释放时调用 [release]。多个嵌套页面分别持有租约，只有最后一个租约
/// 释放后才会关闭原生保护，避免内层弹窗关闭时提前暴露外层敏感页面。
class ScreenSecurityLease {
  ScreenSecurityLease._(this._token, this.state);

  final Object _token;

  /// 获取租约时原生平台返回的保护状态。
  final ScreenSecurityState state;

  bool _released = false;

  Future<ScreenSecurityState> release() async {
    if (_released) return ScreenSecurity.currentState;
    _released = true;
    return ScreenSecurity._release(_token);
  }
}

/// 引用计数式屏幕安全协调器。
class ScreenSecurity {
  ScreenSecurity._();

  static final Set<Object> _activeTokens = <Object>{};
  static Future<void> _operationBarrier = Future<void>.value();
  static ScreenSecurityState _currentState = ScreenSecurityState.disabled;
  static ScreenSecurityOperation _platformOperation =
      platform.setScreenSecurityEnabled;

  static ScreenSecurityState get currentState => _currentState;

  @visibleForTesting
  static int get activeLeaseCount => _activeTokens.length;

  /// 获取一个屏幕保护租约。
  static Future<ScreenSecurityLease> acquire() {
    final token = Object();
    return _serialized(() async {
      final shouldEnable = _activeTokens.isEmpty;
      _activeTokens.add(token);
      if (shouldEnable) {
        _currentState = await _invokePlatform(true);
      }
      return ScreenSecurityLease._(token, _currentState);
    });
  }

  static Future<ScreenSecurityState> _release(Object token) {
    return _serialized(() async {
      if (!_activeTokens.remove(token)) return _currentState;
      if (_activeTokens.isNotEmpty) return _currentState;
      if (_currentState == ScreenSecurityState.enabled) {
        _currentState = await _invokePlatform(false);
      }
      return _currentState;
    });
  }

  static Future<ScreenSecurityState> _invokePlatform(bool enabled) async {
    try {
      return await _platformOperation(enabled);
    } catch (_) {
      return ScreenSecurityState.failed;
    }
  }

  static Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _operationBarrier;
    final completed = Completer<void>();
    _operationBarrier = completed.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        completed.complete();
      }
    }();
  }

  @visibleForTesting
  static void setPlatformOperationForTesting(ScreenSecurityOperation value) {
    assert(_activeTokens.isEmpty);
    _platformOperation = value;
    _currentState = ScreenSecurityState.disabled;
    _operationBarrier = Future<void>.value();
  }

  @visibleForTesting
  static void resetForTesting() {
    assert(_activeTokens.isEmpty);
    _platformOperation = platform.setScreenSecurityEnabled;
    _currentState = ScreenSecurityState.disabled;
    _operationBarrier = Future<void>.value();
  }
}
