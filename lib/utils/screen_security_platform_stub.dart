import 'screen_security_state.dart';

/// Web 和不支持 `dart:io` 的平台明确返回 unsupported。
Future<ScreenSecurityState> setScreenSecurityEnabled(bool enabled) async {
  return ScreenSecurityState.unsupported;
}
