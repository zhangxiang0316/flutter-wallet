import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';

class WalletOverviewCard extends StatelessWidget {
  const WalletOverviewCard({
    super.key,
    required this.wallet,
    required this.wallets,
    required this.totalAssetsText,
    required this.onWalletSelected,
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final String totalAssetsText;
  final ValueChanged<WalletAccount> onWalletSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BalanceHeroCard(
          wallet: wallet,
          wallets: wallets,
          totalAssetsText: totalAssetsText,
          onWalletSelected: onWalletSelected,
        ).marginOnly(bottom: 12.h),
        _PrimaryWalletPanel(
          wallet: wallet,
          wallets: wallets,
          onWalletSelected: onWalletSelected,
        ),
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
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final String totalAssetsText;
  final ValueChanged<WalletAccount> onWalletSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 198.h),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.22),
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
          ),
        ],
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
              ),
              SizedBox(height: 38.h),
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
                        fontSize: 38.sp,
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
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final ValueChanged<WalletAccount> onWalletSelected;

  @override
  Widget build(BuildContext context) {
    final canSwitch = wallets.length > 1;
    return Semantics(
      button: canSwitch,
      label: S.of(context).switchWallet,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: canSwitch
              ? () => _showWalletPicker(
                  context: context,
                  wallet: wallet,
                  wallets: wallets,
                  onWalletSelected: onWalletSelected,
                )
              : null,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            constraints: BoxConstraints(maxWidth: 218.w, minHeight: 52.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WalletAvatar(wallet: wallet, selected: true, size: 34),
                SizedBox(width: 10.w),
                Flexible(
                  child: Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (canSwitch) ...[
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 18.w,
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
  const _PrimaryWalletPanel({
    required this.wallet,
    required this.wallets,
    required this.onWalletSelected,
  });

  final WalletAccount wallet;
  final List<WalletAccount> wallets;
  final ValueChanged<WalletAccount> onWalletSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSwitch = wallets.length > 1;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        onTap: canSwitch
            ? () => _showWalletPicker(
                context: context,
                wallet: wallet,
                wallets: wallets,
                onWalletSelected: onWalletSelected,
              )
            : null,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 78.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: context.appTheme.dividerColor!.withValues(alpha: 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: context.appTheme.cardShadowColor ?? Colors.transparent,
                blurRadius: 12.r,
                offset: Offset(0, 5.h),
              ),
            ],
          ),
          child: Row(
            children: [
              const _ChainOverlapTicker(),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  S.of(context).primaryMultiChainWallet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Semantics(
                button: true,
                label: S.of(context).copyWalletAddress,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tight(Size(40.w, 40.w)),
                  padding: EdgeInsets.zero,
                  onPressed: () => _copyWalletAddress(context, wallet),
                  icon: Icon(
                    Icons.copy_rounded,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    size: 22.w,
                  ),
                  tooltip: S.of(context).copyWalletAddress,
                ),
              ),
            ],
          ),
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
  });

  final WalletAccount wallet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.09)
          : colorScheme.onSurface.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 66.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              _WalletAvatar(wallet: wallet, selected: selected, size: 36),
              SizedBox(width: 11.w),
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
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        _WalletAddressChip(
                          label: 'EVM',
                          address: _shortWalletAddress(wallet.bscAddress),
                        ),
                        _WalletAddressChip(
                          label: WalletChain.tron.symbol,
                          address: _shortWalletAddress(wallet.tronAddress),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        color: colorScheme.primary,
                        size: 20.w,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        key: const ValueKey('normal'),
                        color: colorScheme.onSurface.withValues(alpha: 0.32),
                        size: 20.w,
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
  });

  final WalletAccount wallet;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.primary : colorScheme.onSurface;
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.92)
            : colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        wallet.name.characters.first.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WalletAddressChip extends StatelessWidget {
  const _WalletAddressChip({required this.label, required this.address});

  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.45),
              fontSize: 9.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 5.w),
          Text(
            address,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.64),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      width: 124.w,
      height: 42.w,
      child: Stack(
        children: chains
            .asMap()
            .entries
            .map(
              (entry) => Positioned(
                left: (entry.key * 27).w,
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
      width: 42.w,
      height: 42.w,
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
          fontSize: 17.sp,
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

void _showWalletPicker({
  required BuildContext context,
  required WalletAccount wallet,
  required List<WalletAccount> wallets,
  required ValueChanged<WalletAccount> onWalletSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(sheetContext).switchWallet,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
              ).marginOnly(bottom: 12.h),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.56,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: wallets
                        .map(
                          (item) => _WalletOptionRow(
                            wallet: item,
                            selected: item.id == wallet.id,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              onWalletSelected(item);
                            },
                          ).marginOnly(bottom: 8.h),
                        )
                        .toList(growable: false),
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
