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
import '../../../wallet/adapters/default_chain_adapter_registry.dart';
import '../../../wallet/services/config/wallet_address_book_service.dart';
import '../../../wallet/services/config/wallet_chain_config_service.dart';
import 'widgets/address_book_action_sheet.dart';
import 'widgets/address_book_confirm_dialog.dart';
import 'widgets/address_book_empty_card.dart';
import 'widgets/address_book_entry_sheet.dart';
import 'widgets/address_book_entry_tile.dart';
import 'widgets/address_book_intro_card.dart';

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
  PreferredSizeWidget? getAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Theme.of(context).cardColor,
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
        S.of(context).addressBook,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context).addAddressBookEntry,
          onPressed: () => _showEntrySheet(context),
          icon: Icon(Icons.add_rounded, size: 22.w, color: colorScheme.primary),
        ),
      ],
    );
  }

  @override
  Widget? getBody(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          AddressBookIntroCard(
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
            AddressBookEmptyCard(onAddPressed: () => _showEntrySheet(context))
          else
            ...controller.visibleEntries.map(
              (entry) => AddressBookEntryTile(
                entry: entry,
                selectable: controller.selectable,
                onTap: controller.selectable
                    ? () => Get.back(result: entry.address)
                    : null,
                onMorePressed: () => _showActionSheet(context, entry),
              ).marginOnly(bottom: 10.h),
            ),
        ],
      ),
    );
  }

  void _showEntrySheet(BuildContext context, {WalletAddressBookEntry? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressBookEntrySheet(
        chains: controller.availableChainsForSheet,
        initialEntry: entry,
        fixedChainId: controller.fixedChainId,
        onSubmit: controller.saveEntry,
      ),
    );
  }

  void _showActionSheet(BuildContext context, WalletAddressBookEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressBookActionSheet(
        cancelText: S.of(context).cancel,
        actions: [
          AddressBookAction(
            label: S.of(context).editAddressBookEntry,
            icon: Icons.edit_outlined,
            onTap: () => _showEntrySheet(context, entry: entry),
          ),
          AddressBookAction(
            label: S.of(context).removeContact,
            icon: Icons.delete_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            onTap: () => _confirmRemove(context, entry),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WalletAddressBookEntry entry,
  ) async {
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AddressBookConfirmDialog(
        title: S.of(dialogContext).removeContact,
        message: S.of(dialogContext).removeContactConfirm(entry.name),
        confirmText: S.of(dialogContext).removeContact,
        onConfirm: () => controller.removeEntry(entry),
      ),
    );
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
      createDefaultChainAdapterRegistry()
          .require(chain)
          .normalizeAddress(address);
      return true;
    } catch (_) {
      return false;
    }
  }
}
