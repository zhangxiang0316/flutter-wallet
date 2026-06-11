import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_asset.dart';
import '../../../../wallet/models/wallet_chain.dart';

/// 添加自定义资产底部弹窗。
///
/// 用户在这里输入合约地址、币种符号、名称和精度；EVM 链支持先尝试自动拉取
/// 合约元数据，再提交到控制器保存。
class AddCustomAssetSheet extends StatefulWidget {
  const AddCustomAssetSheet({
    super.key,
    required this.chain,
    required this.onFetchMetadata,
    required this.onSubmit,
  });

  /// 当前正在添加资产的链。
  final WalletChainConfig chain;

  /// 根据合约地址查询链上资产元数据。
  final Future<WalletAsset?> Function({
    required WalletChainConfig chain,
    required String contractAddress,
  })
  onFetchMetadata;

  /// 提交用户最终确认的自定义资产信息。
  final Future<bool> Function({
    required WalletChainConfig chain,
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
  /// 合约地址输入控制器。
  final TextEditingController _contractController = TextEditingController();

  /// 币种符号输入控制器。
  final TextEditingController _symbolController = TextEditingController();

  /// 币种名称输入控制器。
  final TextEditingController _nameController = TextEditingController();

  /// 币种精度输入控制器。
  final TextEditingController _decimalsController = TextEditingController();

  /// 是否正在自动获取合约元数据。
  bool _isFetching = false;

  /// 是否正在提交自定义资产。
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
    // 当前主题色用于按钮、链标签和输入框边框。
    final colorScheme = Theme.of(context).colorScheme;

    // 键盘弹出时给底部弹窗补足避让距离。
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
                          fontSize: 15.sp,
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
                          fontSize: 10.sp,
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
                        textStyle: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
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
                      textStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
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

  /// 根据用户输入的合约地址自动查询资产元数据。
  Future<void> _fetchMetadata() async {
    // 合约地址提交前先去掉首尾空格。
    final contractAddress = _contractController.text.trim();
    if (contractAddress.isEmpty) {
      Toast.show(S.current.customAssetInvalid);
      return;
    }

    setState(() {
      _isFetching = true;
    });

    // 元数据查询失败时服务层返回 null，UI 层只负责提示用户。
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

    // 查询成功后回填表单，允许用户继续手动调整。
    _contractController.text = metadata.contractAddress ?? contractAddress;
    _symbolController.text = metadata.symbol;
    _nameController.text = metadata.name;
    _decimalsController.text = metadata.decimals.toString();
  }

  /// 校验并提交自定义资产表单。
  Future<void> _submit() async {
    // 精度必须是整数，通常来自 ERC20 decimals。
    final decimals = int.tryParse(_decimalsController.text.trim());
    if (decimals == null) {
      Toast.show(S.current.customAssetInvalid);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // 具体地址规范化、重复校验和持久化由控制器完成。
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

/// 自定义资产表单输入框。
///
/// 统一输入框的字号、填充、圆角和聚焦边框样式。
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

  /// 输入框控制器。
  final TextEditingController controller;

  /// 输入框标签。
  final String label;

  /// 输入框占位提示。
  final String hint;

  /// 键盘类型，例如精度字段使用数字键盘。
  final TextInputType? keyboardType;

  /// 键盘动作按钮类型。
  final TextInputAction? textInputAction;

  /// 文本大小写策略，币种符号会使用大写输入。
  final TextCapitalization textCapitalization;

  /// 用户点击键盘提交按钮后的回调。
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // 当前主题色用于输入框背景和聚焦边框。
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.64),
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.36),
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
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
