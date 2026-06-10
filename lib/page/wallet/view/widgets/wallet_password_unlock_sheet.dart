import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';

/// 密码解锁底部弹窗。
///
/// 仅负责收集钱包密码和提交状态，私钥/助记词读取由控制器完成。
class WalletPasswordUnlockSheet extends StatefulWidget {
  const WalletPasswordUnlockSheet({
    super.key,
    required this.title,
    required this.onSubmit,
  });

  /// 弹窗标题，例如查看私钥或查看助记词。
  final String title;

  /// 使用用户输入密码执行解锁，返回 true 时关闭弹窗。
  final Future<bool> Function(String password) onSubmit;

  @override
  State<WalletPasswordUnlockSheet> createState() =>
      _WalletPasswordUnlockSheetState();
}

class _WalletPasswordUnlockSheetState extends State<WalletPasswordUnlockSheet> {
  /// 钱包密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 防止重复提交解锁请求。
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
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
            TextField(
              controller: _passwordController,
              obscureText: true,
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
