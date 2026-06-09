import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../controller/wallet_detail_controller.dart';

@GetXRoutePage('/walletDetail')
// ignore: use_key_in_widget_constructors, must_be_immutable
class WalletDetailPage extends BaseScaffoldPage<WalletDetailController> {
  @override
  WalletDetailController generateController() {
    return WalletDetailController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
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
        S.of(context!).walletDetails,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context!).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context!).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  @override
  Widget? getBody() {
    final wallet = controller.wallet;
    if (wallet == null) {
      return Center(
        child: Text(
          S.of(context!).transferUnavailable,
          style: TextStyle(fontSize: 13.sp),
        ),
      );
    }

    return ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _WalletHeader(
            wallet: wallet,
            isRenaming: controller.isRenamingWallet,
            onRenamePressed: () => _showRenameWalletSheet(wallet.name),
          ),
          SizedBox(height: 12.h),
          _AddressSection(wallet: wallet),
          SizedBox(height: 12.h),
          _SecretSection(
            privateKeyText: controller.privateKeyText,
            mnemonicText: controller.mnemonicText,
            hasMnemonic: controller.hasMnemonic,
            isUnlockingPrivateKey: controller.isUnlockingPrivateKey,
            isUnlockingMnemonic: controller.isUnlockingMnemonic,
            onUnlockPrivateKey: () => _showPasswordUnlockSheet(
              title: S.of(context!).viewPrivateKey,
              onSubmit: controller.unlockPrivateKey,
            ),
            onUnlockMnemonic: () => _showPasswordUnlockSheet(
              title: S.of(context!).viewMnemonic,
              onSubmit: controller.unlockMnemonic,
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameWalletSheet(String currentName) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RenameWalletSheet(
        currentName: currentName,
        onSubmit: controller.renameWallet,
      ),
    );
  }

  void _showPasswordUnlockSheet({
    required String title,
    required Future<bool> Function(String password) onSubmit,
  }) {
    showModalBottomSheet(
      context: context!,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _PasswordUnlockSheet(title: title, onSubmit: onSubmit),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({
    required this.wallet,
    required this.isRenaming,
    required this.onRenamePressed,
  });

  final WalletAccount wallet;
  final bool isRenaming;
  final VoidCallback onRenamePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: _panelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, const Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              _walletInitial(wallet),
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  S.of(context).primaryMultiChainWallet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tight(Size(34.w, 34.w)),
            padding: EdgeInsets.zero,
            onPressed: isRenaming ? null : onRenamePressed,
            icon: isRenaming
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(strokeWidth: 2.w),
                  )
                : Icon(
                    Icons.edit_rounded,
                    size: 17.w,
                    color: colorScheme.primary,
                  ),
            tooltip: S.of(context).editWalletName,
          ),
        ],
      ),
    );
  }
}

class _AddressSection extends StatelessWidget {
  const _AddressSection({required this.wallet});

  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: S.of(context).walletAddresses,
      children: [
        _AddressTile(
          chain: WalletChain.bsc,
          label: WalletChain.bsc.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.ethereum,
          label: WalletChain.ethereum.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.xLayer,
          label: WalletChain.xLayer.name,
          address: wallet.bscAddress,
        ),
        _AddressTile(
          chain: WalletChain.solana,
          label: WalletChain.solana.name,
          address: wallet.solanaAddress,
        ),
        _AddressTile(
          chain: WalletChain.tron,
          label: WalletChain.tron.name,
          address: wallet.tronAddress,
        ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.chain,
    required this.label,
    required this.address,
  });

  final WalletChain chain;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _PlainTile(
      leading: _ChainBadge(chain: chain),
      title: label,
      subtitle: address,
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints.tight(Size(34.w, 34.w)),
        padding: EdgeInsets.zero,
        onPressed: () => _copy(context, address),
        icon: Icon(
          Icons.content_copy_rounded,
          size: 17.w,
          color: colorScheme.onSurface.withValues(alpha: 0.45),
        ),
        tooltip: S.of(context).copied,
      ),
    );
  }
}

class _SecretSection extends StatelessWidget {
  const _SecretSection({
    required this.privateKeyText,
    required this.mnemonicText,
    required this.hasMnemonic,
    required this.isUnlockingPrivateKey,
    required this.isUnlockingMnemonic,
    required this.onUnlockPrivateKey,
    required this.onUnlockMnemonic,
  });

  final String privateKeyText;
  final String mnemonicText;
  final bool hasMnemonic;
  final bool isUnlockingPrivateKey;
  final bool isUnlockingMnemonic;
  final VoidCallback onUnlockPrivateKey;
  final VoidCallback onUnlockMnemonic;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: S.of(context).walletSecrets,
      children: [
        _SecretTile(
          title: S.of(context).viewPrivateKey,
          value: privateKeyText,
          loading: isUnlockingPrivateKey,
          onUnlock: onUnlockPrivateKey,
        ),
        if (hasMnemonic)
          _SecretTile(
            title: S.of(context).viewMnemonic,
            value: mnemonicText,
            loading: isUnlockingMnemonic,
            onUnlock: onUnlockMnemonic,
          ),
      ],
    );
  }
}

class _SecretTile extends StatelessWidget {
  const _SecretTile({
    required this.title,
    required this.value,
    required this.loading,
    required this.onUnlock,
  });

  final String title;
  final String value;
  final bool loading;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final revealed = value.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return _PlainTile(
      leading: Container(
        width: 32.w,
        height: 32.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          Icons.lock_open_rounded,
          size: 17.w,
          color: colorScheme.error,
        ),
      ),
      title: title,
      subtitle: revealed ? value : S.of(context).unlockToView,
      subtitleMaxLines: revealed ? 4 : 1,
      trailing: revealed
          ? IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tight(Size(34.w, 34.w)),
              padding: EdgeInsets.zero,
              onPressed: () => _copy(context, value),
              icon: Icon(
                Icons.content_copy_rounded,
                size: 17.w,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            )
          : IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tight(Size(34.w, 34.w)),
              padding: EdgeInsets.zero,
              onPressed: loading ? null : onUnlock,
              icon: loading
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(strokeWidth: 2.w),
                    )
                  : Icon(
                      Icons.visibility_rounded,
                      size: 18.w,
                      color: colorScheme.primary,
                    ),
            ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
      decoration: _panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
          ).marginOnly(bottom: 8.h),
          ...children,
        ],
      ),
    );
  }
}

class _PlainTile extends StatelessWidget {
  const _PlainTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.subtitleMaxLines = 2,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          leading,
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 10.5.sp,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          trailing,
        ],
      ),
    );
  }
}

class _ChainBadge extends StatelessWidget {
  const _ChainBadge({required this.chain});

  final WalletChain chain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32.w,
      height: 32.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _chainColor(chain).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        chain.symbol.characters.first,
        style: TextStyle(
          color: _chainColor(chain),
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _chainColor(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return const Color(0xFFF0B90B);
      case WalletChain.ethereum:
        return const Color(0xFF627EEA);
      case WalletChain.xLayer:
        return const Color(0xFF10B981);
      case WalletChain.solana:
        return const Color(0xFF14F195);
      case WalletChain.tron:
        return const Color(0xFFE11D48);
    }
  }
}

class _PasswordUnlockSheet extends StatefulWidget {
  const _PasswordUnlockSheet({required this.title, required this.onSubmit});

  final String title;
  final Future<bool> Function(String password) onSubmit;

  @override
  State<_PasswordUnlockSheet> createState() => _PasswordUnlockSheetState();
}

class _PasswordUnlockSheetState extends State<_PasswordUnlockSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
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
              widget.title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
            ).marginOnly(bottom: 14.h),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: S.of(context).walletPassword,
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 18.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ).marginOnly(bottom: 14.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(S.of(context).unlockWallet),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit(password);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }
}

class _RenameWalletSheet extends StatefulWidget {
  const _RenameWalletSheet({required this.currentName, required this.onSubmit});

  final String currentName;
  final Future<bool> Function(String name) onSubmit;

  @override
  State<_RenameWalletSheet> createState() => _RenameWalletSheetState();
}

class _RenameWalletSheetState extends State<_RenameWalletSheet> {
  late final TextEditingController _nameController;
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

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}

void _copy(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  Toast.show(S.of(context).copied);
}

String _walletInitial(WalletAccount wallet) {
  final name = wallet.name.trim();
  if (name.isNotEmpty) {
    return name.characters.first.toUpperCase();
  }
  return 'W';
}
