import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'wallet_sheet_styles.dart';

class ImportWalletSheet extends StatefulWidget {
  const ImportWalletSheet({
    super.key,
    required this.onMnemonicSubmit,
    required this.onPrivateKeySubmit,
    required this.validatePassword,
  });

  final Future<bool> Function(String mnemonic, String password)
  onMnemonicSubmit;
  final Future<bool> Function(String privateKey, String password)
  onPrivateKeySubmit;
  final bool Function(String password, String confirmPassword) validatePassword;

  @override
  State<ImportWalletSheet> createState() => _ImportWalletSheetState();
}

class _ImportWalletSheetState extends State<ImportWalletSheet> {
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _useMnemonic = true;
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
    return VantSheet(
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
            onChanged: (value) {
              setState(() {
                _useMnemonic = value;
                _secretController.clear();
              });
            },
          ).marginOnly(bottom: 14.h),
          TextField(
            controller: _secretController,
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
            label: S.of(context).walletPassword,
            hint: S.of(context).walletPasswordHint,
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
              child: Text(S.of(context).confirmImport),
            ),
          ),
        ],
      ),
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
