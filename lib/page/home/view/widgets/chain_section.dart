import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../generated/l10n.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'home_styles.dart';

class ChainSection extends StatelessWidget {
  const ChainSection({
    super.key,
    required this.wallet,
    required this.balances,
    required this.isLoading,
    required this.onTransferPressed,
  });

  final WalletAccount wallet;
  final List<ChainBalance> balances;
  final bool isLoading;
  final ValueChanged<ChainBalance> onTransferPressed;

  @override
  Widget build(BuildContext context) {
    final bscBalances = balances
        .where((balance) => balance.chain == WalletChain.bsc)
        .toList();
    final xLayerBalances = balances
        .where((balance) => balance.chain == WalletChain.xLayer)
        .toList();
    final tronBalances = balances
        .where((balance) => balance.chain == WalletChain.tron)
        .toList();
    return Column(
      children: [
        _ChainCard(
          chain: WalletChain.bsc,
          address: wallet.bscAddress,
          balances: bscBalances,
          isLoading: isLoading,
          onTransferPressed: onTransferPressed,
        ).marginOnly(bottom: 12.h),
        _ChainCard(
          chain: WalletChain.xLayer,
          address: wallet.bscAddress,
          balances: xLayerBalances,
          isLoading: isLoading,
          onTransferPressed: onTransferPressed,
        ).marginOnly(bottom: 12.h),
        _ChainCard(
          chain: WalletChain.tron,
          address: wallet.tronAddress,
          balances: tronBalances,
          isLoading: isLoading,
          onTransferPressed: onTransferPressed,
        ),
      ],
    );
  }
}

class _ChainCard extends StatelessWidget {
  const _ChainCard({
    required this.chain,
    required this.address,
    required this.balances,
    required this.isLoading,
    required this.onTransferPressed,
  });

  final WalletChain chain;
  final String address;
  final List<ChainBalance> balances;
  final bool isLoading;
  final ValueChanged<ChainBalance> onTransferPressed;

  @override
  Widget build(BuildContext context) {
    final hasError = balances.any((balance) => balance.hasError);
    final chainColor = homeChainColor(chain);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: homePanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  chain.symbol.characters.first,
                  style: TextStyle(
                    color: chainColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 11.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chain.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.58),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).marginOnly(bottom: 12.h),
          ...balances.map(
            (balance) => _AssetRow(
              balance: balance,
              onTransferPressed: onTransferPressed,
            ),
          ),
          if (balances.isEmpty) _EmptyBalancePlaceholder(isLoading: isLoading),
          if (hasError)
            Text(
              S.of(context).balanceLoadFailed,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12.sp,
              ),
            ).marginOnly(top: 8.h),
        ],
      ),
    );
  }
}

class _EmptyBalancePlaceholder extends StatelessWidget {
  const _EmptyBalancePlaceholder({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        isLoading ? S.of(context).loading : '--',
        style: TextStyle(
          fontSize: 14.sp,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.balance, required this.onTransferPressed});

  final ChainBalance balance;
  final ValueChanged<ChainBalance> onTransferPressed;

  @override
  Widget build(BuildContext context) {
    final assetColor = homeAssetColor(context, balance.symbol);
    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: context.appTheme.dividerColor!.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: assetColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              balance.symbol.characters.first,
              style: TextStyle(
                color: assetColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ).marginOnly(right: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.symbol,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  balance.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.56),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 106.w),
                child: Text(
                  '${balance.amount} ${balance.symbol}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(38.w, 38.w)),
                onPressed: () => onTransferPressed(balance),
                icon: Container(
                  width: 34.w,
                  height: 34.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.outbound_rounded,
                    size: 20.w,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                tooltip: S.of(context).transfer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
