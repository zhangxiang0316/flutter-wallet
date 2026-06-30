import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_address_book_entry.dart';
import '../../../../wallet/models/wallet_chain.dart';

/// 新增/编辑联系人的底部弹出表单。
///
/// 包含名称、链选择、地址和备注四个输入字段，提交前进行基础校验。
class AddressBookEntrySheet extends StatefulWidget {
  const AddressBookEntrySheet({
    super.key,
    required this.chains,
    required this.initialEntry,
    required this.fixedChainId,
    required this.onSubmit,
  });

  /// 可选的链列表。
  final List<WalletChainConfig> chains;

  /// 编辑时传入的已有联系人，新增时为 null。
  final WalletAddressBookEntry? initialEntry;

  /// 固定链 ID，不为 null 时链选择器不可更改。
  final String? fixedChainId;

  /// 提交回调，返回 true 表示成功并关闭弹窗。
  final Future<bool> Function({
    String? id,
    required String name,
    required String address,
    required WalletChainConfig chain,
    String note,
  })
  onSubmit;

  @override
  State<AddressBookEntrySheet> createState() => _AddressBookEntrySheetState();
}

class _AddressBookEntrySheetState extends State<AddressBookEntrySheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  WalletChainConfig? _selectedChain;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _addressController = TextEditingController(text: entry?.address ?? '');
    _noteController = TextEditingController(text: entry?.note ?? '');
    _selectedChain = _initialChain();
  }

  WalletChainConfig? _initialChain() {
    final entryChainId = widget.initialEntry?.chainId;
    final fixedChainId = widget.fixedChainId;
    final selectedId = entryChainId?.isNotEmpty == true
        ? entryChainId
        : fixedChainId;
    if (selectedId != null) {
      for (final chain in widget.chains) {
        if (chain.id == selectedId) return chain;
      }
    }
    return widget.chains.isEmpty ? null : widget.chains.first;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 18.w,
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(width: 10.w),
                Text(
                  widget.initialEntry == null
                      ? S.of(context).addAddressBookEntry
                      : S.of(context).editAddressBookEntry,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                context,
                label: S.of(context).contactName,
                hint: S.of(context).contactNameHint,
                icon: Icons.badge_outlined,
              ),
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<WalletChainConfig>(
              initialValue: _selectedChain,
              isExpanded: true,
              decoration: _inputDecoration(
                context,
                label: S.of(context).selectTransferChain,
                icon: Icons.hub_outlined,
              ),
              items: widget.chains
                  .map(
                    (chain) => DropdownMenuItem(
                      value: chain,
                      child: Text(chain.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: widget.fixedChainId == null
                  ? (chain) => setState(() => _selectedChain = chain)
                  : null,
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _addressController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                context,
                label: S.of(context).contactAddress,
                hint: '0x... / T... / Solana',
                icon: Icons.account_circle_outlined,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 2,
              decoration: _inputDecoration(
                context,
                label: S.of(context).contactNote,
                hint: S.of(context).contactNoteHint,
                icon: Icons.notes_outlined,
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(S.of(context).saveContact),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18.w),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final chain = _selectedChain;
    if (chain == null) {
      Toast.show(S.current.contactInvalid);
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit(
      id: widget.initialEntry?.id,
      name: _nameController.text,
      address: _addressController.text,
      chain: chain,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
