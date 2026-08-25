import 'package:flutter/widgets.dart';

import '../utils/sensitive_data_lifecycle.dart';
import 'secure_screen.dart';

/// 敏感页面统一作用域。
///
/// 负责注册/注销后台清理回调，并通过 [SecureScreen] 持有引用计数式屏幕保护。
/// 作用域自身不保存任何私钥、助记词或密码。
class SensitiveDataScope extends StatefulWidget {
  const SensitiveDataScope({
    super.key,
    required this.onClear,
    required this.child,
    this.protectScreen = true,
    this.showProtectionToast = true,
  });

  final VoidCallback onClear;
  final Widget child;
  final bool protectScreen;
  final bool showProtectionToast;

  @override
  State<SensitiveDataScope> createState() => _SensitiveDataScopeState();
}

class _SensitiveDataScopeState extends State<SensitiveDataScope> {
  @override
  void initState() {
    super.initState();
    SensitiveDataLifecycle.register(widget.onClear);
  }

  @override
  void didUpdateWidget(SensitiveDataScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onClear != widget.onClear) {
      SensitiveDataLifecycle.unregister(oldWidget.onClear);
      SensitiveDataLifecycle.register(widget.onClear);
    }
  }

  @override
  void dispose() {
    SensitiveDataLifecycle.unregister(widget.onClear);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      enabled: widget.protectScreen,
      showToast: widget.showProtectionToast,
      child: widget.child,
    );
  }
}
