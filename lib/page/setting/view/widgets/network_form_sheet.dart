import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_chain.dart';

/// 新增/编辑网络的底部弹出表单。
///
/// 包含网络名称、符号、Chain ID、RPC URL 和区块浏览器 API 等输入字段；
/// 编辑模式下 Chain ID 不可修改，RPC URL 支持多行输入。
class NetworkFormSheet extends StatefulWidget {
  const NetworkFormSheet({
    super.key,
    required this.onSubmit,
    this.initialChain,
  });

  /// 编辑时传入的已有链配置，新增时为 null。
  final WalletChainConfig? initialChain;

  /// 提交回调，返回 true 表示成功并关闭弹窗。
  final Future<bool> Function({
    required String name,
    required String symbol,
    required int chainId,
    required List<String> rpcUrls,
    String? explorerApiUrl,
    String? explorerApiKey,
  })
  onSubmit;

  @override
  State<NetworkFormSheet> createState() => _NetworkFormSheetState();
}

class _NetworkFormSheetState extends State<NetworkFormSheet> {
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _chainIdController = TextEditingController();
  final _rpcController = TextEditingController();
  final _explorerApiController = TextEditingController();
  final _explorerKeyController = TextEditingController();

  bool _isSubmitting = false;

  bool get _isEditing => widget.initialChain != null;

  bool get _requiresChainId =>
      !_isEditing || (widget.initialChain?.isEvm ?? true);

  bool get _supportsExplorerApi =>
      !_isEditing || (widget.initialChain?.isEvm ?? true);

  @override
  void initState() {
    super.initState();
    final chain = widget.initialChain;
    if (chain == null) return;
    _nameController.text = chain.name;
    _symbolController.text = chain.symbol;
    _chainIdController.text = chain.evmChainId?.toString() ?? '';
    _rpcController.text = chain.rpcUrls.join('\n');
    _explorerApiController.text = chain.explorerApiUrl ?? '';
    _explorerKeyController.text = chain.explorerApiKey ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _chainIdController.dispose();
    _rpcController.dispose();
    _explorerApiController.dispose();
    _explorerKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;
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
                Text(
                  _isEditing
                      ? S.of(context).editNetwork
                      : S.of(context).addNetwork,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 14.h),
                _NetworkTextField(
                  controller: _nameController,
                  label: S.of(context).networkName,
                  hint: 'Polygon',
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12.h),
                _NetworkTextField(
                  controller: _symbolController,
                  label: S.of(context).networkSymbol,
                  hint: 'MATIC',
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: 12.h),
                if (_requiresChainId) ...[
                  _NetworkTextField(
                    controller: _chainIdController,
                    label: S.of(context).networkChainId,
                    hint: widget.initialChain?.evmChainId?.toString() ?? '137',
                    keyboardType: TextInputType.number,
                    readOnly: _isEditing,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 12.h),
                ],
                _NetworkTextField(
                  controller: _rpcController,
                  label: S.of(context).networkRpcUrl,
                  hint:
                      'https://polygon-rpc.com\n'
                      'https://polygon-bor-rpc.publicnode.com',
                  helperText: S.of(context).networkRpcUrlHelper,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 5,
                ),
                if (_supportsExplorerApi) ...[
                  SizedBox(height: 12.h),
                  _NetworkTextField(
                    controller: _explorerApiController,
                    label: S.of(context).networkExplorerApiUrl,
                    hint: 'https://api.etherscan.io/api',
                    helperText: S.of(context).networkExplorerApiUrlHelper,
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 12.h),
                  _NetworkTextField(
                    controller: _explorerKeyController,
                    label: S.of(context).networkExplorerApiKey,
                    hint: 'API Key',
                    textInputAction: TextInputAction.done,
                  ),
                ],
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      textStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                        : Icon(
                            _isEditing
                                ? Icons.save_outlined
                                : Icons.add_rounded,
                            size: 18.w,
                          ),
                    label: Text(
                      _isEditing
                          ? S.of(context).saveNetwork
                          : S.of(context).addNetwork,
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

  Future<void> _submit() async {
    final chainId = int.tryParse(_chainIdController.text.trim());
    final rpcUrls = _rpcController.text
        .split(RegExp(r'[\n,]'))
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if ((_requiresChainId && chainId == null) || rpcUrls.isEmpty) {
      Toast.show(S.current.networkInvalid);
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    final success = await widget.onSubmit(
      name: _nameController.text,
      symbol: _symbolController.text,
      chainId: chainId ?? widget.initialChain?.evmChainId ?? 0,
      rpcUrls: rpcUrls,
      explorerApiUrl: _explorerApiController.text,
      explorerApiKey: _explorerKeyController.text,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (success) {
      Navigator.of(context).pop();
    }
  }
}

/// 网络表单中的通用文本输入框。
///
/// 统一设置标签、占位、图标和边框样式。
class _NetworkTextField extends StatelessWidget {
  const _NetworkTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    this.minLines = 1,
    this.maxLines = 1,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? helperText;
  final int minLines;
  final int maxLines;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      readOnly: readOnly,
      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
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
        helperStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 10.sp,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        isDense: true,
        filled: true,
        fillColor: colorScheme.onSurface.withValues(alpha: 0.035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }
}
