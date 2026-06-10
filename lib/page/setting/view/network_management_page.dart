import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_chain_config_service.dart';
import '../../../wallet/services/wallet_custom_asset_service.dart';

@GetXRoutePage('/networkManagement')
/// 网络管理页面。
///
/// 第一版只允许用户新增 EVM 网络。内置链不可删除，但可以编辑名称、简称和 RPC；
/// 用户添加的链可以隐藏、编辑或删除。
// ignore: use_key_in_widget_constructors, must_be_immutable
class NetworkManagementPage
    extends BaseScaffoldPage<NetworkManagementController> {
  @override
  NetworkManagementController generateController() {
    return NetworkManagementController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 50.h,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: Get.back,
      ),
      centerTitle: true,
      title: Text(
        S.of(context!).networkManagement,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context!).addNetwork,
          onPressed: _showAddNetworkSheet,
          icon: Icon(Icons.add_rounded, size: 22.w, color: colorScheme.primary),
        ),
      ],
    );
  }

  @override
  Widget? getBody() {
    return ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _NetworkIntroCard(),
          SizedBox(height: 12.h),
          ...controller.chains.map(
            (chain) => _NetworkTile(
              chain: chain,
              onEnabledChanged: chain.isBuiltin
                  ? null
                  : (enabled) => controller.setEnabled(chain, enabled),
              onEditPressed: () => _showEditNetworkSheet(chain),
              onRemovePressed: chain.isBuiltin
                  ? null
                  : () => _confirmRemoveChain(chain),
            ).marginOnly(bottom: 10.h),
          ),
        ],
      ),
    );
  }

  void _showAddNetworkSheet() {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _NetworkFormSheet(onSubmit: controller.addEvmChain),
    );
  }

  void _showEditNetworkSheet(WalletChainConfig chain) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _NetworkFormSheet(
        initialChain: chain,
        onSubmit:
            ({
              required name,
              required symbol,
              required chainId,
              required rpcUrls,
            }) {
              return controller.updateNetwork(
                chain: chain,
                name: name,
                symbol: symbol,
                rpcUrls: rpcUrls,
              );
            },
      ),
    );
  }

  Future<void> _confirmRemoveChain(WalletChainConfig chain) async {
    final confirmed = await showDialog<bool>(
      context: context!,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(dialogContext).removeNetwork),
        content: Text(S.of(dialogContext).removeNetworkConfirm(chain.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).removeNetwork),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.removeChain(chain);
    }
  }
}

class NetworkManagementController extends BaseController {
  NetworkManagementController({
    WalletChainConfigService? service,
    WalletCustomAssetService? customAssetService,
  }) : _service = service ?? WalletChainConfigService(),
       _customAssetService = customAssetService ?? WalletCustomAssetService();

  final WalletChainConfigService _service;
  final WalletCustomAssetService _customAssetService;

  List<WalletChainConfig> chains = [];

  bool isSubmitting = false;

  @override
  void onInit() {
    super.onInit();
    loadChains();
  }

  Future<void> loadChains() async {
    chains = await _service.loadAllChains();
    update();
  }

  Future<bool> addEvmChain({
    required String name,
    required String symbol,
    required int chainId,
    required List<String> rpcUrls,
  }) async {
    if (isSubmitting) return false;
    try {
      isSubmitting = true;
      update();
      await _service.addCustomEvmChain(
        name: name,
        symbol: symbol,
        evmChainId: chainId,
        rpcUrls: rpcUrls,
      );
      Toast.show(S.current.networkAdded);
      await loadChains();
      return true;
    } on WalletChainConfigDuplicateException {
      Toast.show(S.current.networkDuplicate);
      return false;
    } on WalletChainConfigRpcMismatchException {
      Toast.show(S.current.networkRpcMismatch);
      return false;
    } on WalletChainConfigRpcUnavailableException {
      Toast.show(S.current.networkRpcUnavailable);
      return false;
    } catch (_) {
      Toast.show(S.current.networkInvalid);
      return false;
    } finally {
      isSubmitting = false;
      update();
    }
  }

  Future<void> setEnabled(WalletChainConfig chain, bool enabled) async {
    await _service.setCustomChainEnabled(chainId: chain.id, enabled: enabled);
    await loadChains();
  }

  Future<bool> updateNetwork({
    required WalletChainConfig chain,
    required String name,
    required String symbol,
    required List<String> rpcUrls,
  }) async {
    if (isSubmitting) return false;
    try {
      isSubmitting = true;
      update();
      if (chain.isBuiltin) {
        await _service.updateBuiltinChain(
          chainId: chain.id,
          name: name,
          symbol: symbol,
          rpcUrls: rpcUrls,
        );
      } else {
        await _service.updateCustomEvmChain(
          chainId: chain.id,
          name: name,
          symbol: symbol,
          rpcUrls: rpcUrls,
        );
      }
      Toast.show(S.current.networkUpdated);
      await loadChains();
      return true;
    } on WalletChainConfigRpcMismatchException {
      Toast.show(S.current.networkRpcMismatch);
      return false;
    } on WalletChainConfigRpcUnavailableException {
      Toast.show(S.current.networkRpcUnavailable);
      return false;
    } catch (_) {
      Toast.show(S.current.networkInvalid);
      return false;
    } finally {
      isSubmitting = false;
      update();
    }
  }

  Future<void> removeChain(WalletChainConfig chain) async {
    final assets = await _customAssetService.loadCustomAssets();
    await _customAssetService.saveCustomAssets(
      assets
          .where((asset) => asset.chainId != chain.id)
          .toList(growable: false),
    );
    await _service.removeCustomChain(chain.id);
    Toast.show(S.current.networkRemoved);
    await loadChains();
  }
}

class _NetworkIntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(13.w),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.hub_outlined,
              color: colorScheme.primary,
              size: 18.w,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              S.of(context).networkManagementTip,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontSize: 12.sp,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.chain,
    required this.onEnabledChanged,
    required this.onEditPressed,
    required this.onRemovePressed,
  });

  final WalletChainConfig chain;
  final ValueChanged<bool>? onEnabledChanged;
  final VoidCallback? onEditPressed;
  final VoidCallback? onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final color = Color(chain.colorValue ?? 0xFF2563EB);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              chain.symbol.characters.first,
              style: TextStyle(
                color: color,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chain.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  chain.isEvm
                      ? '${chain.symbol} · Chain ID ${chain.evmChainId}'
                      : chain.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.52),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: chain.isEnabled, onChanged: onEnabledChanged),
          if (onEditPressed != null)
            IconButton(
              tooltip: S.of(context).editNetwork,
              onPressed: onEditPressed,
              icon: Icon(
                Icons.edit_outlined,
                size: 19.w,
                color: colorScheme.primary,
              ),
            ),
          if (onRemovePressed != null)
            IconButton(
              tooltip: S.of(context).removeNetwork,
              onPressed: onRemovePressed,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20.w,
                color: colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkFormSheet extends StatefulWidget {
  const _NetworkFormSheet({required this.onSubmit, this.initialChain});

  final WalletChainConfig? initialChain;

  final Future<bool> Function({
    required String name,
    required String symbol,
    required int chainId,
    required List<String> rpcUrls,
  })
  onSubmit;

  @override
  State<_NetworkFormSheet> createState() => _NetworkFormSheetState();
}

class _NetworkFormSheetState extends State<_NetworkFormSheet> {
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _chainIdController = TextEditingController();
  final _rpcController = TextEditingController();

  bool _isSubmitting = false;

  bool get _isEditing => widget.initialChain != null;

  bool get _requiresChainId =>
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _chainIdController.dispose();
    _rpcController.dispose();
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
                    fontSize: 17.sp,
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
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
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
      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        isDense: true,
        filled: true,
        fillColor: colorScheme.onSurface.withValues(alpha: 0.035),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}
