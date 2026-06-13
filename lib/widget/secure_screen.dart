import 'package:flutter/material.dart';

import '../generated/l10n.dart';
import '../utils/screen_security.dart';
import '../utils/toast_util.dart';

/// 安全屏幕 Widget。
///
/// 包裹需要保护的页面或组件，自动启用和禁用截屏保护。
/// 进入时启用保护，离开时恢复正常。
/// 首次进入时会显示提示信息，告知用户截屏保护已启用。
///
/// 使用示例:
/// ```dart
/// SecureScreen(
///   child: Scaffold(
///     body: Text('敏感信息'),
///   ),
/// )
/// ```
class SecureScreen extends StatefulWidget {
  const SecureScreen({
    super.key,
    required this.child,
    this.enabled = true,
    this.showToast = true,
  });

  /// 需要保护的子组件。
  final Widget child;

  /// 是否启用保护，默认为 true。
  ///
  /// 可以通过这个参数动态控制是否启用保护。
  final bool enabled;

  /// 是否显示提示 Toast，默认为 true。
  ///
  /// 首次进入时会显示提示，告知用户截屏保护已启用。
  final bool showToast;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _enableSecurity();
      // 延迟显示提示，避免页面动画冲突
      if (widget.showToast) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Toast.show(
              S.current.screenshotProtectionEnabled,
              displayTime: const Duration(seconds: 3),
            );
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(SecureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _enableSecurity();
      } else {
        _disableSecurity();
      }
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      _disableSecurity();
    }
    super.dispose();
  }

  /// 启用截屏保护。
  Future<void> _enableSecurity() async {
    await ScreenSecurity.enable();
  }

  /// 禁用截屏保护。
  Future<void> _disableSecurity() async {
    await ScreenSecurity.disable();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
