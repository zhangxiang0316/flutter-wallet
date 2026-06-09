import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import 'wallet_sheet_styles.dart';

/// 首页需要用户输入钱包密码时的解锁面板。
///
/// 当前用于补全 Solana 地址等需要解密密钥的维护流程，输入正确密码后由
/// [onSubmit] 执行实际操作。
class PasswordUnlockSheet extends StatefulWidget {
  const PasswordUnlockSheet({
    super.key,
    required this.title,
    required this.detail,
    required this.submitLabel,
    required this.onSubmit,
  });

  /// 面板标题。
  final String title;

  /// 标题下方的流程说明。
  final String detail;

  /// 主按钮文案。
  final String submitLabel;

  /// 使用用户输入的密码执行解锁后的操作，返回 true 时关闭弹窗。
  final Future<bool> Function(String password) onSubmit;

  @override
  State<PasswordUnlockSheet> createState() => _PasswordUnlockSheetState();
}

class _PasswordUnlockSheetState extends State<PasswordUnlockSheet> {
  /// 钱包密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 防止用户重复点击提交按钮。
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VantSheet(
      bottomInset: MediaQuery.of(context).viewInsets.bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VantSheetTitle(title: widget.title),
          Text(
            widget.detail,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.35,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ).marginOnly(bottom: 14.h),
          PasswordTextField(
            controller: _passwordController,
            label: S.of(context).walletPassword,
          ).marginOnly(bottom: 14.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: vantFilledButtonStyle(context),
              onPressed: _isSubmitting ? null : _submit,
              child: Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // 密码两端都去掉首尾空格，避免误输入空格导致校验失败。
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }

    setState(() => _isSubmitting = true);

    // 解锁后的实际维护操作由父页面/控制器执行。
    final ok = await widget.onSubmit(password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}
