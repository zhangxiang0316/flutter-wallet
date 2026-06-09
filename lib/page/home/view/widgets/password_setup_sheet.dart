import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../controller/home_controller.dart';
import 'wallet_sheet_styles.dart';

class PasswordSetupSheet extends StatefulWidget {
  const PasswordSetupSheet({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.isDismissible,
    required this.onSubmit,
    required this.validatePassword,
  });

  final String title;
  final String submitLabel;
  final bool isDismissible;
  final Future<Object?> Function(String password) onSubmit;
  final bool Function(String password, String confirmPassword) validatePassword;

  @override
  State<PasswordSetupSheet> createState() => _PasswordSetupSheetState();
}

class _PasswordSetupSheetState extends State<PasswordSetupSheet> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
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
      canPop: widget.isDismissible,
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
          label: S.of(context).walletPassword,
        ).marginOnly(bottom: 12.h),
        PasswordTextField(
          controller: _confirmPasswordController,
          label: S.of(context).confirmWalletPassword,
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
    );
  }

  Widget _buildMnemonicBackupStep(BuildContext context, String mnemonic) {
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
    final password = _passwordController.text.trim();
    if (!widget.validatePassword(
      password,
      _confirmPasswordController.text.trim(),
    )) {
      return;
    }

    setState(() => _isSubmitting = true);
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

class _MnemonicWordGrid extends StatelessWidget {
  const _MnemonicWordGrid({required this.words});

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
