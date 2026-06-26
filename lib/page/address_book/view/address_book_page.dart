import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_address_book_entry.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_address_book_service.dart';
import '../../../wallet/services/wallet_chain_config_service.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

class AddressBookPageArguments {
  const AddressBookPageArguments({
    this.chainId,
    this.chainName,
    this.selectable = false,
  });

  final String? chainId;
  final String? chainName;
  final bool selectable;
}

@GetXRoutePage('/addressBook')
/// 地址簿页面。
///
/// 设置页进入时展示全部联系人；转账页进入时会按当前链过滤，并点击返回地址。
// ignore: use_key_in_widget_constructors, must_be_immutable
class AddressBookPage extends BaseScaffoldPage<AddressBookController> {
  @override
  AddressBookController generateController() {
    return AddressBookController();
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
        S.of(context!).addressBook,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context!).addAddressBookEntry,
          onPressed: () => _showEntrySheet(),
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
          _AddressBookIntroCard(
            chainName: controller.fixedChainName,
            selectable: controller.selectable,
          ),
          SizedBox(height: 12.h),
          if (controller.isLoading)
            Padding(
              padding: EdgeInsets.only(top: 48.h),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.w)),
            )
          else if (controller.visibleEntries.isEmpty)
            _AddressBookEmptyCard(onAddPressed: () => _showEntrySheet())
          else
            ...controller.visibleEntries.map(
              (entry) => _AddressBookEntryTile(
                entry: entry,
                selectable: controller.selectable,
                onTap: controller.selectable
                    ? () => Get.back(result: entry.address)
                    : null,
                onEditPressed: () => _showEntrySheet(entry: entry),
                onRemovePressed: () => _confirmRemove(entry),
              ).marginOnly(bottom: 10.h),
            ),
        ],
      ),
    );
  }

  void _showEntrySheet({WalletAddressBookEntry? entry}) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressBookEntrySheet(
        chains: controller.availableChainsForSheet,
        initialEntry: entry,
        fixedChainId: controller.fixedChainId,
        onSubmit: controller.saveEntry,
      ),
    );
  }

  Future<void> _confirmRemove(WalletAddressBookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context!,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.of(dialogContext).removeContact),
        content: Text(S.of(dialogContext).removeContactConfirm(entry.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).removeContact),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.removeEntry(entry);
    }
  }
}

class AddressBookController extends BaseController {
  AddressBookController({
    WalletAddressBookService? service,
    WalletChainConfigService? chainService,
  }) : _service = service ?? WalletAddressBookService(),
       _chainService = chainService ?? WalletChainConfigService();

  final WalletAddressBookService _service;
  final WalletChainConfigService _chainService;

  AddressBookPageArguments arguments = const AddressBookPageArguments();
  List<WalletAddressBookEntry> entries = [];
  List<WalletChainConfig> chains = [];
  bool isLoading = false;

  String? get fixedChainId => arguments.chainId;

  String? get fixedChainName => arguments.chainName;

  bool get selectable => arguments.selectable;

  List<WalletAddressBookEntry> get visibleEntries {
    final chainId = fixedChainId;
    if (chainId == null || chainId.isEmpty) return entries;
    return entries.where((entry) => entry.chainId == chainId).toList();
  }

  List<WalletChainConfig> get availableChainsForSheet {
    final chainId = fixedChainId;
    if (chainId == null || chainId.isEmpty) return chains;
    return chains.where((chain) => chain.id == chainId).toList();
  }

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is AddressBookPageArguments) {
      arguments = value;
    }
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    update();
    chains = await _chainService.loadAllChains();
    entries = await _service.loadEntries();
    isLoading = false;
    update();
  }

  Future<bool> saveEntry({
    String? id,
    required String name,
    required String address,
    required WalletChainConfig chain,
    String note = '',
  }) async {
    if (name.trim().isEmpty || address.trim().isEmpty) {
      Toast.show(S.current.contactInvalid);
      return false;
    }
    if (!_isAddressValid(chain, address.trim())) {
      Toast.show(S.current.contactInvalid);
      return false;
    }
    await _service.saveEntry(
      id: id,
      name: name,
      address: address,
      chainId: chain.id,
      chainName: chain.name,
      note: note,
    );
    Toast.show(S.current.contactSaved);
    await loadData();
    return true;
  }

  Future<void> removeEntry(WalletAddressBookEntry entry) async {
    await _service.removeEntry(entry.id);
    Toast.show(S.current.contactRemoved);
    await loadData();
  }

  bool _isAddressValid(WalletChainConfig chain, String address) {
    try {
      switch (chain.type) {
        case WalletChainType.evm:
          WalletTransferService.normalizeEvmAddress(address);
          return true;
        case WalletChainType.tron:
          WalletTransferService.tronAddressToHex(address);
          return true;
        case WalletChainType.solana:
          WalletTransferService.normalizeSolanaAddress(address);
          return true;
      }
    } catch (_) {
      return false;
    }
  }
}

class _AddressBookIntroCard extends StatelessWidget {
  const _AddressBookIntroCard({this.chainName, required this.selectable});

  final String? chainName;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = selectable && (chainName?.isNotEmpty ?? false)
        ? '${S.of(context).selectContact} · $chainName'
        : S.of(context).addressBook;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: _panelDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              Icons.contacts_rounded,
              size: 18.w,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  S.of(context).addressBookTip,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 11.5.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressBookEmptyCard extends StatelessWidget {
  const _AddressBookEmptyCard({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: _panelDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            size: 34.w,
            color: colorScheme.primary,
          ),
          SizedBox(height: 8.h),
          Text(
            S.of(context).noContacts,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 12.h),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(S.of(context).addAddressBookEntry),
          ),
        ],
      ),
    );
  }
}

class _AddressBookEntryTile extends StatelessWidget {
  const _AddressBookEntryTile({
    required this.entry,
    required this.selectable,
    required this.onTap,
    required this.onEditPressed,
    required this.onRemovePressed,
  });

  final WalletAddressBookEntry entry;
  final bool selectable;
  final VoidCallback? onTap;
  final VoidCallback onEditPressed;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: _panelDecoration(context),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  selectable
                      ? Icons.call_made_rounded
                      : Icons.person_outline_rounded,
                  color: colorScheme.primary,
                  size: 18.w,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          entry.chainName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _shortAddress(entry.address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.note.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        entry.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.46),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: S.of(context).more,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditPressed();
                  } else if (value == 'remove') {
                    onRemovePressed();
                  }
                },
                itemBuilder: (menuContext) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(S.of(menuContext).editAddressBookEntry),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(S.of(menuContext).removeContact),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressBookEntrySheet extends StatefulWidget {
  const _AddressBookEntrySheet({
    required this.chains,
    required this.initialEntry,
    required this.fixedChainId,
    required this.onSubmit,
  });

  final List<WalletChainConfig> chains;
  final WalletAddressBookEntry? initialEntry;
  final String? fixedChainId;
  final Future<bool> Function({
    String? id,
    required String name,
    required String address,
    required WalletChainConfig chain,
    String note,
  })
  onSubmit;

  @override
  State<_AddressBookEntrySheet> createState() => _AddressBookEntrySheetState();
}

class _AddressBookEntrySheetState extends State<_AddressBookEntrySheet> {
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

BoxDecoration _panelDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
  );
}

String _shortAddress(String address) {
  if (address.length <= 18) return address;
  return '${address.substring(0, 10)}...${address.substring(address.length - 6)}';
}
