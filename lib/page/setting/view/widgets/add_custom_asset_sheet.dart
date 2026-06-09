import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_asset.dart';
import '../../../../wallet/models/wallet_chain.dart';

class AddCustomAssetSheet extends StatefulWidget {
  const AddCustomAssetSheet({
    super.key,
    required this.chain,
    required this.onFetchMetadata,
    required this.onSubmit,
  });

  final WalletChain chain;
  final Future<WalletAsset?> Function({
    required WalletChain chain,
    required String contractAddress,
  })
  onFetchMetadata;
  final Future<bool> Function({
    required WalletChain chain,
    required String contractAddress,
    required String symbol,
    required String name,
    required int decimals,
  })
  onSubmit;

  @override
  State<AddCustomAssetSheet> createState() => _AddCustomAssetSheetState();
}

class _AddCustomAssetSheetState extends State<AddCustomAssetSheet> {
  final TextEditingController _contractController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _decimalsController = TextEditingController();

  bool _isFetching = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contractController.dispose();
    _symbolController.dispose();
    _nameController.dispose();
    _decimalsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colorScheme.outline.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.of(context).addCustomAsset,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        widget.chain.name,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _CustomAssetTextField(
                  controller: _contractController,
                  label: S.of(context).customAssetContractAddress,
                  hint: S.of(context).customAssetContractHint,
                  textInputAction: TextInputAction.next,
                ),
                if (widget.chain.isEvm) ...[
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isFetching ? null : _fetchMetadata,
                      icon: _isFetching
                          ? SizedBox(
                              width: 15.w,
                              height: 15.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(Icons.auto_awesome_rounded, size: 16.w),
                      label: Text(S.of(context).fetchTokenInfo),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 11.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                _CustomAssetTextField(
                  controller: _symbolController,
                  label: S.of(context).customAssetSymbol,
                  hint: 'USDT',
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12.h),
                _CustomAssetTextField(
                  controller: _nameController,
                  label: S.of(context).customAssetName,
                  hint: 'Tether USD',
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12.h),
                _CustomAssetTextField(
                  controller: _decimalsController,
                  label: S.of(context).customAssetDecimals,
                  hint: '18',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 15.w,
                            height: 15.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(Icons.add_rounded, size: 18.w),
                    label: Text(S.of(context).addCustomAsset),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchMetadata() async {
    final contractAddress = _contractController.text.trim();
    if (contractAddress.isEmpty) {
      Toast.show(S.current.customAssetInvalid);
      return;
    }

    setState(() {
      _isFetching = true;
    });
    final metadata = await widget.onFetchMetadata(
      chain: widget.chain,
      contractAddress: contractAddress,
    );
    if (!mounted) return;
    setState(() {
      _isFetching = false;
    });

    if (metadata == null) {
      Toast.show(S.current.customAssetMetadataUnavailable);
      return;
    }
    _contractController.text = metadata.contractAddress ?? contractAddress;
    _symbolController.text = metadata.symbol;
    _nameController.text = metadata.name;
    _decimalsController.text = metadata.decimals.toString();
  }

  Future<void> _submit() async {
    final decimals = int.tryParse(_decimalsController.text.trim());
    if (decimals == null) {
      Toast.show(S.current.customAssetInvalid);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    final success = await widget.onSubmit(
      chain: widget.chain,
      contractAddress: _contractController.text.trim(),
      symbol: _symbolController.text.trim(),
      name: _nameController.text.trim(),
      decimals: decimals,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (success) {
      Toast.show(S.current.customAssetAdded);
      Navigator.of(context).pop();
    }
  }
}

class _CustomAssetTextField extends StatelessWidget {
  const _CustomAssetTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
    );
  }
}
