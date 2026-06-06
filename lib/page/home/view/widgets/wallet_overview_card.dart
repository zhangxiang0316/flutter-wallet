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
      padding: EdgeInsets.all(18.w),
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
              size: 118.w,
              color: Colors.white.withValues(alpha: 0.08),
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
              ).marginOnly(bottom: 24.h),
              Text(
                S.of(context).totalAssets,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13.sp,
                ),
              ),
              Text(
                totalAssetsText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ).marginOnly(top: 4.h),
              SizedBox(height: 18.h),
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
    return PopupMenuButton<String>(
      tooltip: S.of(context).switchWallet,
      enabled: wallets.length > 1,
      position: PopupMenuPosition.under,
      onSelected: (walletId) {
        final selectedWallet = wallets.firstWhere(
          (item) => item.id == walletId,
          orElse: () => wallet,
        );
        onWalletSelected(selectedWallet);
      },
      itemBuilder: (context) {
        return wallets
            .map((item) {
              final selected = item.id == wallet.id;
              return PopupMenuItem<String>(
                value: item.id,
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        item.name.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
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
                            item.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _shortAddress(item.bscAddress),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18.w,
                      ),
                  ],
                ),
              );
            })
            .toList(growable: false);
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(7.r),
                ),
                child: Text(
                  wallet.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  wallet.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (wallets.length > 1) ...[
                SizedBox(width: 5.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.88),
                  size: 19.w,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortAddress(String address) {
    if (address.length <= 12) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
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
                width: 22.w,
                height: 22.w,
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
                    fontSize: 10.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_rounded,
            color: Colors.white.withValues(alpha: 0.76),
            size: 16.w,
          ).marginOnly(right: 8.w),
          Expanded(
            child: Text(
              _shortAddress(wallet.bscAddress),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            WalletChain.tron.symbol,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              _shortAddress(wallet.tronAddress),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
