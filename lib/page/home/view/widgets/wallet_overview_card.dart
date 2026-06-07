import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, const Color(0xFF0F766E), 0.38)!,
            const Color(0xFF102A43),
          ],
        ),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16.w,
            top: -18.h,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 112.w,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WalletSwitcherButton(
                      wallet: wallet,
                      wallets: wallets,
                      onWalletSelected: onWalletSelected,
                    ),
                  ),
                  _ChainTicker(),
                ],
              ).marginOnly(bottom: 22.h),
              Row(
                children: [
                  Icon(
                    Icons.stacked_line_chart_rounded,
                    size: 15.w,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    S.of(context).totalAssets,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    totalAssetsText,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                ),
              ).marginOnly(top: 4.h),
              SizedBox(height: 16.h),
              _AddressStrip(wallet: wallet),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletSwitcherButton extends StatelessWidget {
  const _WalletSwitcherButton({
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
      button: true,
      label: S.of(context).switchWallet,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8.r),
          child: InkWell(
            onTap: canSwitch ? () => _showWalletPicker(context) : null,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: 52.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  _WalletAvatar(wallet: wallet, selected: true, size: 34),
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
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Text(
                              'EVM',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 5.w),
                            Expanded(
                              child: Text(
                                _shortWalletAddress(wallet.bscAddress),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canSwitch) ...[
                    SizedBox(width: 8.w),
                    Container(
                      width: 26.w,
                      height: 26.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white.withValues(alpha: 0.84),
                        size: 16.w,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWalletPicker(BuildContext context) {
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
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
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
            ? Colors.white.withValues(alpha: 0.9)
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

String _shortWalletAddress(String address) {
  if (address.length <= 12) {
    return address;
  }
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

class _ChainTicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chains = [
      WalletChain.bsc,
      WalletChain.ethereum,
      WalletChain.xLayer,
      WalletChain.tron,
    ];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: chains
            .map(
              (chain) => Container(
                width: 21.w,
                height: 21.w,
                alignment: Alignment.center,
                margin: EdgeInsets.only(left: chain == chains.first ? 0 : 4.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(7.r),
                ),
                child: Text(
                  chain.symbol.characters.first,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _AddressStrip extends StatelessWidget {
  const _AddressStrip({required this.wallet});

  final WalletAccount wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final evmBadge = _AddressBadge(
            label: 'EVM',
            address: _shortAddress(wallet.bscAddress),
          );
          final tronBadge = _AddressBadge(
            label: WalletChain.tron.symbol,
            address: _shortAddress(wallet.tronAddress),
          );
          if (constraints.maxWidth < 306.w) {
            return Column(
              children: [
                evmBadge,
                SizedBox(height: 6.h),
                tronBadge,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: evmBadge),
              SizedBox(width: 8.w),
              Expanded(child: tronBadge),
            ],
          );
        },
      ),
    );
  }

  String _shortAddress(String address) {
    if (address.length <= 14) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

class _AddressBadge extends StatelessWidget {
  const _AddressBadge({required this.label, required this.address});

  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 32.h),
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 9.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 7.w),
          Expanded(
            child: Text(
              address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
