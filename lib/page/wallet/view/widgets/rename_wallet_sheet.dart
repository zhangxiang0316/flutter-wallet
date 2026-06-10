import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';

/// 修改钱包名称底部弹窗。
class RenameWalletSheet extends StatefulWidget {
  const RenameWalletSheet({
    super.key,
    required this.currentName,
    required this.onSubmit,
  });

  /// 当前钱包名称，用于初始化输入框。
  final String currentName;

  /// 提交新名称，返回 true 时关闭弹窗。
  final Future<bool> Function(String name) onSubmit;

  @override
  State<RenameWalletSheet> createState() => _RenameWalletSheetState();
}

class _RenameWalletSheetState extends State<RenameWalletSheet> {
  /// 钱包名称输入控制器。
  late final TextEditingController _nameController;

  /// 防止重复提交改名请求。
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
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
              S.of(context).editWalletName,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
            ).marginOnly(bottom: 14.h),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 24,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: S.of(context).walletName,
                prefixIcon: Icon(Icons.badge_outlined, size: 18.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ).marginOnly(bottom: 14.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(S.of(context).cancel),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(S.of(context).saveWalletName),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 校验名称非空并提交改名请求。
  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Toast.show(S.current.walletNameRequired);
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}
