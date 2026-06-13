import 'dart:io';

import 'package:flutter/services.dart';

/// 屏幕安全服务。
///
/// 提供截屏保护功能，防止敏感信息通过截屏泄露。
class ScreenSecurity {
  static const MethodChannel _channel = MethodChannel('screen_security');

  /// 启用截屏保护。
  ///
  /// Android: 设置 FLAG_SECURE，阻止截屏和录屏
  /// iOS: 在截屏时显示遮罩层（需要原生实现）
  static Future<void> enable() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('enable');
      } catch (e) {
        // 静默失败，不影响正常使用
        // 开发环境下可以打印日志
        // developer.log('Failed to enable screen security: $e');
      }
    }
  }

  /// 禁用截屏保护。
  ///
  /// 恢复正常的截屏功能。
  static Future<void> disable() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('disable');
      } catch (e) {
        // 静默失败
      }
    }
  }
}
