import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'wallet_sheet_styles.dart';

/// 首页导入钱包底部表单。
///
/// 支持助记词和私钥两种导入方式，并要求用户为导入的钱包设置本地加密密码。
/// 表单只处理输入、模式切换和提交状态，具体导入逻辑由父页面/控制器提供。
class ImportWalletSheet extends StatefulWidget {
  const ImportWalletSheet({
    super.key,
    required this.onMnemonicSubmit,
    required this.onPrivateKeySubmit,
    required this.validatePassword,
  });

  /// 使用助记词导入钱包，返回 true 时关闭弹窗。
  final Future<bool> Function(String mnemonic, String password)
  onMnemonicSubmit;

  /// 使用私钥导入钱包，返回 true 时关闭弹窗。
  final Future<bool> Function(String privateKey, String password)
  onPrivateKeySubmit;

  /// 校验密码和确认密码，失败时由调用方负责展示错误提示。
  final bool Function(String password, String confirmPassword) validatePassword;

  @override
  State<ImportWalletSheet> createState() => _ImportWalletSheetState();
}

class _ImportWalletSheetState extends State<ImportWalletSheet> {
  /// 助记词或私钥输入控制器，具体含义由 [_useMnemonic] 决定。
  final TextEditingController _secretController = TextEditingController();

  /// 钱包本地加密密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 确认密码输入控制器。
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// true 表示当前输入助记词，false 表示当前输入私钥。
  bool _useMnemonic = true;

  /// 防止重复点击提交按钮触发多次导入。
  bool _isSubmitting = false;

  @override
  void dispose() {
    _secretController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: VantSheet(
        bottomInset: MediaQuery.of(context).viewInsets.bottom,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VantSheetTitle(title: S.of(context).importWallet),
            VantSegmentedControl(
              leftLabel: S.of(context).importMnemonic,
              rightLabel: S.of(context).importPrivateKey,
              leftSelected: _useMnemonic,
              enabled: !_isSubmitting,
              onChanged: (value) {
                setState(() {
                  _useMnemonic = value;
                  _secretController.clear();
                });
              },
            ).marginOnly(bottom: 14.h),
            TextField(
              controller: _secretController,
              enabled: !_isSubmitting,
              minLines: _useMnemonic ? 3 : 2,
              maxLines: _useMnemonic ? 5 : 4,
              decoration: vantInputDecoration(
                context,
                label: _useMnemonic
                    ? S.of(context).mnemonic
                    : S.of(context).importPrivateKey,
                hintText: _useMnemonic
                    ? S.of(context).mnemonicHint
                    : S.of(context).privateKeyHint,
                prefixIcon: _useMnemonic
                    ? Icons.password_rounded
                    : Icons.key_rounded,
              ),
            ).marginOnly(bottom: 14.h),
            PasswordTextField(
              controller: _passwordController,
              enabled: !_isSubmitting,
              label: S.of(context).walletPassword,
              hint: S.of(context).walletPasswordHint,
            ).marginOnly(bottom: 12.h),
            PasswordTextField(
              controller: _confirmPasswordController,
              enabled: !_isSubmitting,
              label: S.of(context).confirmWalletPassword,
            ).marginOnly(bottom: 14.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: vantFilledButtonStyle(context),
                onPressed: _isSubmitting ? null : _submit,
                child: VantButtonLoadingLabel(
                  label: S.of(context).confirmImport,
                  loading: _isSubmitting,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // 密码两端都去掉首尾空格，避免用户误输入空格导致无法解锁。
    final password = _passwordController.text.trim();
    if (!widget.validatePassword(
      password,
      _confirmPasswordController.text.trim(),
    )) {
      return;
    }

    setState(() => _isSubmitting = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // 根据当前导入模式调用对应控制器方法。
    final ok = _useMnemonic
        ? await widget.onMnemonicSubmit(_secretController.text, password)
        : await widget.onPrivateKeySubmit(_secretController.text, password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}
