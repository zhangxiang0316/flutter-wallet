import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'home_styles.dart';

class WalletOverviewCard extends StatelessWidget {
  const WalletOverviewCard({
    super.key,
    required this.wallet,
    required this.wallets,
    required this.totalAssetsText,
    required this.onWalletSelected,
    required this.onWalletRemoved,
    required this.onAddWallet,
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final String totalAssetsText;
  final ValueChanged<WalletAccount> onWalletSelected;
  final Future<void> Function(WalletAccount wallet) onWalletRemoved;
  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BalanceHeroCard(
          wallet: wallet,
          wallets: wallets,
          totalAssetsText: totalAssetsText,
          onWalletSelected: onWalletSelected,
          onWalletRemoved: onWalletRemoved,
          onAddWallet: onAddWallet,
        ).marginOnly(bottom: 12.h),
        _PrimaryWalletPanel(wallet: wallet),
      ],
    );
  }
}

class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({
    required this.wallet,
    required this.wallets,
    required this.totalAssetsText,
    required this.onWalletSelected,
    required this.onWalletRemoved,
    required this.onAddWallet,
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final String totalAssetsText;
  final ValueChanged<WalletAccount> onWalletSelected;
  final Future<void> Function(WalletAccount wallet) onWalletRemoved;
  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 186.h),
      padding: EdgeInsets.fromLTRB(16.w, 15.h, 16.w, 17.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2EA8F2),
            Color.lerp(colorScheme.primary, const Color(0xFF0EA5E9), 0.5)!,
            const Color(0xFF102A43),
          ],
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -2.w,
            top: 8.h,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 112.w,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WalletNamePill(
                wallet: wallet,
                wallets: wallets,
                onWalletSelected: onWalletSelected,
                onWalletRemoved: onWalletRemoved,
                onAddWallet: onAddWallet,
              ),
              SizedBox(height: 30.h),
              Align(
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: FittedBox(
                    key: ValueKey(totalAssetsText),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      totalAssetsText,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 9.h),
              Align(
                alignment: Alignment.center,
                child: Text(
                  '${S.of(context).totalAssets} (USD)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletNamePill extends StatelessWidget {
  const _WalletNamePill({
    required this.wallet,
    required this.wallets,
    required this.onWalletSelected,
    required this.onWalletRemoved,
    required this.onAddWallet,
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final ValueChanged<WalletAccount> onWalletSelected;
  final Future<void> Function(WalletAccount wallet) onWalletRemoved;
  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    final canOpen = wallets.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: canOpen,
      label: S.of(context).switchWallet,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999.r),
        child: InkWell(
          onTap: canOpen
              ? () => _showWalletPicker(
                  context: context,
                  wallet: wallet,
                  wallets: wallets,
                  onWalletSelected: onWalletSelected,
                  onWalletRemoved: onWalletRemoved,
                  onAddWallet: onAddWallet,
                )
              : null,
          borderRadius: BorderRadius.circular(999.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(maxWidth: 246.w, minHeight: 43.h),
            padding: EdgeInsets.fromLTRB(6.w, 5.h, 8.w, 5.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WalletAvatar(
                  wallet: wallet,
                  selected: true,
                  onDark: true,
                  size: 32,
                ),
                SizedBox(width: 9.w),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _shortWalletAddress(wallet.bscAddress),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canOpen) ...[
                  SizedBox(width: 8.w),
                  Container(
                    width: 24.w,
                    height: 24.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: colorScheme.onPrimary,
                      size: 17.w,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryWalletPanel extends StatelessWidget {
  const _PrimaryWalletPanel({required this.wallet});

  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 68.h),
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 11.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: homeDividerColor(context)),
        ),
        child: Row(
          children: [
            const _ChainOverlapTicker(),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).primaryMultiChainWallet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    'EVM ${_shortWalletAddress(wallet.bscAddress)}  TRX ${_shortWalletAddress(wallet.tronAddress)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: homeSubTextColor(context),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Semantics(
              button: true,
              label: S.of(context).copyWalletAddress,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tight(Size(34.w, 34.w)),
                padding: EdgeInsets.zero,
                onPressed: () => _copyWalletAddress(context, wallet),
                icon: Icon(
                  Icons.content_copy_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.48),
                  size: 18.w,
                ),
                tooltip: S.of(context).copyWalletAddress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyWalletAddress(BuildContext context, WalletAccount wallet) {
    Clipboard.setData(
      ClipboardData(
        text: 'EVM: ${wallet.bscAddress}\nTRX: ${wallet.tronAddress}',
      ),
    );
    Toast.show(S.of(context).copied);
  }
}

class _WalletOptionRow extends StatelessWidget {
  const _WalletOptionRow({
    required this.wallet,
    required this.selected,
    required this.onTap,
    required this.onRemovePressed,
  });

  final WalletAccount wallet;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.07)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 62.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3.w,
                height: 34.h,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(width: 9.w),
              _WalletAvatar(wallet: wallet, selected: selected, size: 36),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      wallet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    _WalletAddressLine(
                      bscAddress: wallet.bscAddress,
                      tronAddress: wallet.tronAddress,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Semantics(
                button: true,
                label: S.of(context).removeWallet,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tight(Size(32.w, 32.w)),
                  padding: EdgeInsets.zero,
                  onPressed: onRemovePressed,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error.withValues(alpha: 0.72),
                    size: 18.w,
                  ),
                  tooltip: S.of(context).removeWallet,
                ),
              ),
              SizedBox(width: 4.w),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Container(
                        key: const ValueKey('selected'),
                        width: 24.w,
                        height: 24.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: colorScheme.onPrimary,
                          size: 15.w,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: const ValueKey('normal'),
                        color: colorScheme.onSurface.withValues(alpha: 0.26),
                        size: 19.w,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletAvatar extends StatelessWidget {
  const _WalletAvatar({
    required this.wallet,
    required this.selected,
    this.size = 28,
    this.onDark = false,
  });

  final WalletAccount wallet;
  final bool selected;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = onDark || selected
        ? Colors.white
        : colorScheme.onSurface.withValues(alpha: 0.72);
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDark || !selected
            ? Colors.white.withValues(alpha: onDark ? 0.18 : 0)
            : null,
        gradient: selected && !onDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, const Color(0xFF0EA5E9)],
              )
            : null,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.24)
              : colorScheme.onSurface.withValues(alpha: selected ? 0 : 0.08),
        ),
      ),
      child: Text(
        _walletInitial(wallet),
        style: TextStyle(
          color: foreground,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WalletAddressLine extends StatelessWidget {
  const _WalletAddressLine({
    required this.bscAddress,
    required this.tronAddress,
  });

  final String bscAddress;
  final String tronAddress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface.withValues(alpha: 0.52);
    return Row(
      children: [
        Expanded(
          child: _WalletAddressText(
            label: 'EVM',
            address: _shortWalletAddress(bscAddress),
            color: textColor,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _WalletAddressText(
            label: WalletChain.tron.symbol,
            address: _shortWalletAddress(tronAddress),
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _WalletAddressText extends StatelessWidget {
  const _WalletAddressText({
    required this.label,
    required this.address,
    required this.color,
  });

  final String label;
  final String address;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $address',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChainOverlapTicker extends StatelessWidget {
  const _ChainOverlapTicker();

  @override
  Widget build(BuildContext context) {
    final chains = [
      WalletChain.bsc,
      WalletChain.ethereum,
      WalletChain.xLayer,
      WalletChain.tron,
    ];
    return SizedBox(
      width: 100.w,
      height: 34.w,
      child: Stack(
        children: chains
            .asMap()
            .entries
            .map(
              (entry) => Positioned(
                left: (entry.key * 22).w,
                top: 0,
                child: _ChainCircle(chain: entry.value),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ChainCircle extends StatelessWidget {
  const _ChainCircle({required this.chain});

  final WalletChain chain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _chainColor(chain),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).cardColor, width: 2.w),
      ),
      child: Text(
        _chainLabel(chain),
        style: TextStyle(
          color: Colors.white,
          fontSize: 13.sp,
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
      case WalletChain.tron:
        return const Color(0xFFE11D48);
    }
  }

  String _chainLabel(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return 'B';
      case WalletChain.ethereum:
        return 'E';
      case WalletChain.xLayer:
        return 'O';
      case WalletChain.tron:
        return 'T';
    }
  }
}

String _shortWalletAddress(String address) {
  if (address.length <= 12) {
    return address;
  }
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

String _walletInitial(WalletAccount wallet) {
  final name = wallet.name.trim();
  if (name.isNotEmpty) {
    return name.characters.first.toUpperCase();
  }
  return 'W';
}

class _WalletPickerHeader extends StatelessWidget {
  const _WalletPickerHeader({required this.onAddWallet});

  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context).switchWallet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: S.of(context).addWallet,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tight(Size(34.w, 34.w)),
            padding: EdgeInsets.zero,
            onPressed: onAddWallet,
            icon: Container(
              width: 28.w,
              height: 28.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: colorScheme.primary,
                size: 20.w,
              ),
            ),
            tooltip: S.of(context).addWallet,
          ),
        ),
        SizedBox(width: 8.w),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints.tight(Size(32.w, 32.w)),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.close_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20.w,
          ),
        ),
      ],
    );
  }
}

class _CurrentWalletPreview extends StatelessWidget {
  const _CurrentWalletPreview({required this.wallet});

  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _WalletAvatar(wallet: wallet, selected: true, size: 40),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wallet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6.h),
                _WalletAddressLine(
                  bscAddress: wallet.bscAddress,
                  tronAddress: wallet.tronAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showWalletPicker({
  required BuildContext context,
  required WalletAccount wallet,
  required List<WalletAccount> wallets,
  required ValueChanged<WalletAccount> onWalletSelected,
  required Future<void> Function(WalletAccount wallet) onWalletRemoved,
  required VoidCallback onAddWallet,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        top: false,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(top: 9.h, bottom: 14.h),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: _WalletPickerHeader(
                  onAddWallet: () {
                    Navigator.of(sheetContext).pop();
                    onAddWallet();
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: _CurrentWalletPreview(wallet: wallet),
              ).marginOnly(bottom: 10.h),
              Padding(
                padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 18.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.48,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: wallets.length,
                    separatorBuilder: (_, _) => SizedBox(height: 2.h),
                    itemBuilder: (_, index) {
                      final item = wallets[index];
                      return _WalletOptionRow(
                        wallet: item,
                        selected: item.id == wallet.id,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onWalletSelected(item);
                        },
                        onRemovePressed: () async {
                          final shouldRemove = await _confirmRemoveWallet(
                            sheetContext,
                            item,
                          );
                          if (!shouldRemove || !sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          await onWalletRemoved(item);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _confirmRemoveWallet(
  BuildContext context,
  WalletAccount wallet,
) async {
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(S.of(dialogContext).removeWallet),
            content: Text(
              S.of(dialogContext).removeWalletConfirmMessage(wallet.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(S.of(dialogContext).cancel),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(S.of(dialogContext).removeWallet),
              ),
            ],
          );
        },
      ) ??
      false;
}
