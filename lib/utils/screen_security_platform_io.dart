import 'dart:io';

import 'package:flutter/services.dart';

import 'screen_security_state.dart';

const MethodChannel _channel = MethodChannel('screen_security');

/// Android/iOS 调用原生保护；桌面平台明确返回 unsupported。
Future<ScreenSecurityState> setScreenSecurityEnabled(bool enabled) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return ScreenSecurityState.unsupported;
  }
  try {
    await _channel.invokeMethod<void>(enabled ? 'enable' : 'disable');
    return enabled ? ScreenSecurityState.enabled : ScreenSecurityState.disabled;
  } on MissingPluginException {
    return ScreenSecurityState.unsupported;
  } on PlatformException {
    return ScreenSecurityState.failed;
  } catch (_) {
    return ScreenSecurityState.failed;
  }
}
