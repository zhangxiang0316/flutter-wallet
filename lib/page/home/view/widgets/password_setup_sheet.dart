import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../controller/home_controller.dart';
import 'wallet_sheet_styles.dart';

/// 首页创建钱包或密钥迁移时使用的密码设置面板。
///
/// 提交成功后，如果控制器返回 [CreatedWalletBackup]，组件会切换到助记词备份步骤；
/// 如果返回 true，则表示普通加密/迁移流程完成并关闭弹窗。
class PasswordSetupSheet extends StatefulWidget {
  const PasswordSetupSheet({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.isDismissible,
    required this.onSubmit,
    required this.validatePassword,
  });

  /// 面板标题，例如“创建钱包”或“钱包安全升级”。
  final String title;

  /// 主按钮文案，由不同流程决定。
  final String submitLabel;

  /// 是否允许用户手势关闭；安全迁移流程会禁止关闭。
  final bool isDismissible;

  /// 使用用户输入的密码执行创建或迁移动作。
  final Future<Object?> Function(String password) onSubmit;

  /// 校验密码和确认密码，失败时由调用方负责展示错误提示。
  final bool Function(String password, String confirmPassword) validatePassword;

  @override
  State<PasswordSetupSheet> createState() => _PasswordSetupSheetState();
}

class _PasswordSetupSheetState extends State<PasswordSetupSheet> {
  /// 钱包本地加密密码输入控制器。
  final TextEditingController _passwordController = TextEditingController();

  /// 确认密码输入控制器。
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// 防止用户重复点击提交按钮。
  bool _isSubmitting = false;

  /// 创建钱包成功后展示的助记词；为空时展示密码输入步骤。
  String? _mnemonic;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isDismissible && !_isSubmitting,
      child: VantSheet(
        showHandle: widget.isDismissible,
        bottomInset: MediaQuery.of(context).viewInsets.bottom,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _mnemonic == null
              ? _buildPasswordStep(context)
              : _buildMnemonicBackupStep(context, _mnemonic!),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(BuildContext context) {
    return Column(
      key: const ValueKey('password-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VantSheetTitle(title: widget.title),
        Text(
          S.of(context).walletPasswordHint,
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
          enabled: !_isSubmitting,
          label: S.of(context).walletPassword,
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
              label: widget.submitLabel,
              loading: _isSubmitting,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMnemonicBackupStep(BuildContext context, String mnemonic) {
    // 助记词按空格拆分后逐个编号展示。
    final words = mnemonic.split(' ');
    return Column(
      key: const ValueKey('mnemonic-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VantSheetTitle(title: S.of(context).backupMnemonic),
        Text(
          S.of(context).backupMnemonicTip,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.35,
            color: Theme.of(context).colorScheme.error,
          ),
        ).marginOnly(bottom: 14.h),
        _MnemonicWordGrid(words: words).marginOnly(bottom: 14.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: vantFilledButtonStyle(context),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.of(context).mnemonicBackupConfirm),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // 密码两端都去掉首尾空格，避免创建后用户无法用预期密码解锁。
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

    // 创建钱包可能返回助记词备份信息，迁移流程通常返回 bool。
    final result = await widget.onSubmit(password);
    if (!mounted) return;
    if (result is CreatedWalletBackup) {
      setState(() {
        _mnemonic = result.mnemonic;
        _isSubmitting = false;
      });
      return;
    }
    if (result == true) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}

/// 助记词备份网格。
///
/// 将助记词按序号拆成固定三列展示，便于用户逐词核对和抄写。
class _MnemonicWordGrid extends StatelessWidget {
  const _MnemonicWordGrid({required this.words});

  /// 已按空格拆分后的助记词列表。
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: words.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8.h,
          crossAxisSpacing: 8.w,
          childAspectRatio: 2.85,
        ),
        itemBuilder: (context, index) {
          return Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              '${index + 1}. ${words[index]}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }
}
