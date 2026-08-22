import 'package:flutter/foundation.dart';

/// 应用内敏感明文的统一生命周期协调器。
///
/// 持有私钥、助记词等临时明文的页面注册清理回调，应用进入非活动或后台状态时
/// 由应用入口统一触发。这里只保存回调，不保存任何敏感值。
class SensitiveDataLifecycle {
  SensitiveDataLifecycle._();

  static final Set<VoidCallback> _clearCallbacks = <VoidCallback>{};

  /// 注册敏感数据清理回调。
  static void register(VoidCallback callback) {
    _clearCallbacks.add(callback);
  }

  /// 页面释放时移除清理回调，避免控制器被意外保留。
  static void unregister(VoidCallback callback) {
    _clearCallbacks.remove(callback);
  }

  /// 立即清理所有仍处于活动状态的敏感明文。
  static void clearAll() {
    for (final callback in List<VoidCallback>.of(_clearCallbacks)) {
      callback();
    }
  }

  @visibleForTesting
  static void reset() {
    _clearCallbacks.clear();
  }
}
