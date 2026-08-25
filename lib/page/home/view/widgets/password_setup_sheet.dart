import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/services/config/wallet_backup_status_service.dart';
import '../../../../widget/sensitive_data_scope.dart';
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
    this.submittingLabel,
    this.submittingHint,
    required this.isDismissible,
    required this.onSubmit,
    required this.validatePassword,
  });

  /// 面板标题，例如“创建钱包”或“钱包安全升级”。
  final String title;

  /// 主按钮文案，由不同流程决定。
  final String submitLabel;

  /// 提交中的按钮文案；为空时沿用 [submitLabel]。
  final String? submittingLabel;

  /// 提交中的状态说明；设置后会用明确的进度卡片替换密码输入区。
  final String? submittingHint;

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

  /// 创建钱包成功后的钱包 ID。
  String? _walletId;

  /// 是否进入助记词抽词确认步骤。
  bool _isConfirmingMnemonic = false;

  /// 抽词确认输入控制器。
  final List<TextEditingController> _confirmWordControllers = [];

  final WalletBackupStatusService _backupStatusService =
      WalletBackupStatusService();

  int _sensitiveEpoch = 0;

  late final VoidCallback _sensitiveClearCallback = _clearSensitiveData;

  @override
  void dispose() {
    _clearSensitiveData(notify: false);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (final controller in _confirmWordControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SensitiveDataScope(
      onClear: _sensitiveClearCallback,
      child: PopScope(
        canPop: widget.isDismissible && !_isSubmitting,
        child: VantSheet(
          showHandle: widget.isDismissible,
          bottomInset: MediaQuery.of(context).viewInsets.bottom,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _mnemonic == null
                ? _buildPasswordStep(context)
                : _isConfirmingMnemonic
                ? _buildMnemonicConfirmStep(context, _mnemonic!)
                : _buildMnemonicBackupStep(context, _mnemonic!),
          ),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isSubmitting && widget.submittingHint != null
              ? _WalletSubmittingStatus(
                  label: widget.submittingLabel ?? widget.submitLabel,
                  hint: widget.submittingHint!,
                ).marginOnly(bottom: 14.h)
              : Column(
                  key: const ValueKey('password-inputs'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: vantFilledButtonStyle(context),
            onPressed: _isSubmitting ? null : _submit,
            child: VantButtonLoadingLabel(
              label: _isSubmitting
                  ? widget.submittingLabel ?? widget.submitLabel
                  : widget.submitLabel,
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
            onPressed: _startMnemonicConfirm,
            child: Text(S.of(context).mnemonicBackupNext),
          ),
        ),
      ],
    );
  }

  Widget _buildMnemonicConfirmStep(BuildContext context, String mnemonic) {
    final words = mnemonic.split(' ');
    final indexes = _confirmIndexes(words.length);
    _ensureConfirmControllers(indexes.length);
    return Column(
      key: const ValueKey('mnemonic-confirm-step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VantSheetTitle(title: S.of(context).confirmMnemonicBackup),
        Text(
          S.of(context).confirmMnemonicBackupTip,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.35,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ).marginOnly(bottom: 14.h),
        ...indexes.asMap().entries.map((entry) {
          final inputIndex = entry.key;
          final wordIndex = entry.value;
          return TextField(
            controller: _confirmWordControllers[inputIndex],
            textInputAction: inputIndex == indexes.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            enabled: !_isSubmitting,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: S.of(context).mnemonicWordNumber(wordIndex + 1),
              prefixIcon: const Icon(Icons.key_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onSubmitted: (_) {
              if (inputIndex == indexes.length - 1) {
                _confirmMnemonicBackup();
              }
            },
          ).marginOnly(bottom: 12.h);
        }),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(42.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _isConfirmingMnemonic = false),
                child: Text(S.of(context).backToMnemonic),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: FilledButton(
                style: vantFilledButtonStyle(context),
                onPressed: _isSubmitting ? null : _confirmMnemonicBackup,
                child: VantButtonLoadingLabel(
                  label: S.of(context).mnemonicBackupConfirm,
                  loading: _isSubmitting,
                ),
              ),
            ),
          ],
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

    final requestEpoch = _sensitiveEpoch;
    FocusManager.instance.primaryFocus?.unfocus();
    // 密码已复制到当前异步调用后，立即清空输入控制器，避免在助记词备份期间继续
    // 将敏感信息保留在 Widget 的文本缓冲区中。创建失败时用户需要重新输入。
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() => _isSubmitting = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (requestEpoch != _sensitiveEpoch) {
      setState(() => _isSubmitting = false);
      return;
    }

    // 创建钱包可能返回助记词备份信息，迁移流程通常返回 bool。
    final result = await widget.onSubmit(password);
    if (!mounted) return;
    if (requestEpoch != _sensitiveEpoch) {
      await _finishInterruptedSubmission(
        succeeded: result == true || result is CreatedWalletBackup,
      );
      return;
    }
    if (result is CreatedWalletBackup) {
      setState(() {
        _walletId = result.walletId;
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

  void _startMnemonicConfirm() {
    setState(() {
      _isConfirmingMnemonic = true;
      for (final controller in _confirmWordControllers) {
        controller.clear();
      }
    });
  }

  Future<void> _confirmMnemonicBackup() async {
    if (_isSubmitting) return;
    final mnemonic = _mnemonic;
    final walletId = _walletId;
    if (mnemonic == null || walletId == null) return;
    final requestEpoch = _sensitiveEpoch;

    final words = mnemonic.split(' ');
    final indexes = _confirmIndexes(words.length);
    for (final entry in indexes.asMap().entries) {
      final input = _confirmWordControllers[entry.key].text
          .trim()
          .toLowerCase();
      final expected = words[entry.value].trim().toLowerCase();
      if (input != expected) {
        Toast.show(S.current.mnemonicBackupVerifyFailed);
        return;
      }
    }

    setState(() => _isSubmitting = true);
    await _backupStatusService.markMnemonicBackedUp(walletId);
    if (!mounted) return;
    if (requestEpoch != _sensitiveEpoch) {
      await _finishInterruptedSubmission(succeeded: true);
      return;
    }
    _clearSensitiveData();
    Toast.show(S.current.mnemonicBackedUp);
    Navigator.of(context).pop();
  }

  void _ensureConfirmControllers(int count) {
    while (_confirmWordControllers.length < count) {
      _confirmWordControllers.add(TextEditingController());
    }
  }

  List<int> _confirmIndexes(int wordCount) {
    if (wordCount <= 0) return const [];
    final candidates = <int>{1, 4, 8};
    return candidates
        .where((index) => index >= 0 && index < wordCount)
        .toList(growable: false);
  }

  void _clearSensitiveData({bool notify = true}) {
    _sensitiveEpoch++;
    _passwordController.clear();
    _confirmPasswordController.clear();
    for (final controller in _confirmWordControllers) {
      controller.clear();
    }
    _mnemonic = null;
    _walletId = null;
    _isConfirmingMnemonic = false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (notify && mounted) setState(() {});
  }

  Future<void> _finishInterruptedSubmission({required bool succeeded}) async {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!succeeded) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await Navigator.of(context).maybePop();
  }
}

/// 创建钱包等耗时提交过程的可感知状态。
class _WalletSubmittingStatus extends StatelessWidget {
  const _WalletSubmittingStatus({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$label $hint',
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('wallet-submitting-status'),
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      hint,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 11.sp,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
