import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/biometric_auth.dart';
import '../../../../utils/toast_util.dart';

/// 密码解锁底部弹窗。
///
/// 支持生物识别快速解锁，失败后降级到密码输入。
/// 仅负责收集钱包密码和提交状态，私钥/助记词读取由控制器完成。
class WalletPasswordUnlockSheet extends StatefulWidget {
  const WalletPasswordUnlockSheet({
    super.key,
    required this.title,
    required this.onSubmit,
    this.enableBiometric = true,
    this.cachedPassword,
  });

  /// 弹窗标题，例如查看私钥或查看助记词。
  final String title;

  /// 使用用户输入密码执行解锁，返回 true 时关闭弹窗。
  final Future<bool> Function(String password) onSubmit;

  /// 是否启用生物识别，默认为 true。
  final bool enableBiometric;

  /// 缓存的密码（生物识别成功后使用）。
  final String? cachedPassword;

  @override
  State<WalletPasswordUnlockSheet> createState() =>
      _WalletPasswordUnlockSheetState();
}

class _WalletPasswordUnlockSheetState extends State<WalletPasswordUnlockSheet> {
  /// 钱包密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 防止重复提交解锁请求。
  bool _isSubmitting = false;

  /// 是否支持生物识别。
  bool _biometricAvailable = false;

  /// 是否显示密码输入框（生物识别失败后显示）。
  bool _showPasswordField = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndTryAuth();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// 检查生物识别是否可用，并尝试自动认证。
  Future<void> _checkBiometricAndTryAuth() async {
    if (!widget.enableBiometric) {
      setState(() => _showPasswordField = true);
      return;
    }

    final available = await BiometricAuth.isAvailable();
    setState(() => _biometricAvailable = available);

    if (available) {
      // 设备支持生物识别，显示指纹按钮
      // 注意：当前未实现密码缓存，所以生物识别成功后仍需用户首次输入密码
      setState(() => _showPasswordField = false);
    } else {
      // 不支持生物识别，直接显示密码输入框
      setState(() => _showPasswordField = true);
    }
  }

  /// 使用生物识别认证。
  Future<void> _authenticateWithBiometric() async {
    final authenticated = await BiometricAuth.authenticate(
      localizedReason: S.current.authenticateToUnlock,
    );

    if (!mounted) return;

    if (authenticated) {
      // 生物识别成功
      if (widget.cachedPassword != null) {
        // 有缓存密码，直接使用
        setState(() => _isSubmitting = true);
        final ok = await widget.onSubmit(widget.cachedPassword!);
        if (!mounted) return;

        if (ok) {
          Navigator.of(context).pop();
        } else {
          // 密码无效（可能被更改），显示密码输入框
          Toast.show(S.current.invalidWalletPassword);
          setState(() {
            _isSubmitting = false;
            _showPasswordField = true;
          });
        }
      } else {
        // 没有缓存密码，显示密码输入框让用户输入
        // 未来可以在这里缓存用户输入的密码
        setState(() => _showPasswordField = true);
      }
    } else {
      // 生物识别失败，显示密码输入框
      Toast.show(S.current.biometricAuthFailed);
      setState(() => _showPasswordField = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          16.w,
          18.h,
          16.w,
          MediaQuery.of(context).viewInsets.bottom + 18.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
            ).marginOnly(bottom: 14.h),

            // 生物识别按钮
            if (_biometricAvailable && !_showPasswordField)
              Center(
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.fingerprint,
                        size: 64.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _authenticateWithBiometric,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      S.of(context).useBiometric,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: () {
                        setState(() => _showPasswordField = true);
                      },
                      child: Text(S.of(context).orUsePassword),
                    ),
                  ],
                ),
              ).marginOnly(bottom: 14.h),

            // 密码输入框
            if (_showPasswordField) ...[
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: S.of(context).walletPassword,
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 18.w),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ).marginOnly(bottom: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(S.of(context).unlockWallet),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 校验密码非空并提交解锁请求。
  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit(password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}
