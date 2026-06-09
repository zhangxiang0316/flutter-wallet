import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import 'wallet_sheet_styles.dart';

class PasswordUnlockSheet extends StatefulWidget {
  const PasswordUnlockSheet({
    super.key,
    required this.title,
    required this.detail,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final String detail;
  final String submitLabel;
  final Future<bool> Function(String password) onSubmit;

  @override
  State<PasswordUnlockSheet> createState() => _PasswordUnlockSheetState();
}

class _PasswordUnlockSheetState extends State<PasswordUnlockSheet> {
  final TextEditingController _passwordController = TextEditingController();

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
