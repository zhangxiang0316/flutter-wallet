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
    required this.isChainExpanded,
    required this.onChainToggle,
    required this.onTransferPressed,
  });

  final WalletAccount wallet;
  final List<ChainBalance> balances;
  final bool isLoading;
  final bool Function(WalletChain chain) isChainExpanded;
  final ValueChanged<WalletChain> onChainToggle;
  final ValueChanged<ChainBalance> onTransferPressed;

  @override
  Widget build(BuildContext context) {
    final bscBalances = balances
        .where((balance) => balance.chain == WalletChain.bsc)
        .toList();
    final ethereumBalances = balances
        .where((balance) => balance.chain == WalletChain.ethereum)
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
          isExpanded: isChainExpanded(WalletChain.bsc),
          onToggle: onChainToggle,
          onTransferPressed: onTransferPressed,
        ).marginOnly(bottom: 12.h),
        _ChainCard(
          chain: WalletChain.ethereum,
          address: wallet.bscAddress,
          balances: ethereumBalances,
          isLoading: isLoading,
          isExpanded: isChainExpanded(WalletChain.ethereum),
          onToggle: onChainToggle,
          onTransferPressed: onTransferPressed,
        ).marginOnly(bottom: 12.h),
        _ChainCard(
          chain: WalletChain.xLayer,
          address: wallet.bscAddress,
          balances: xLayerBalances,
          isLoading: isLoading,
          isExpanded: isChainExpanded(WalletChain.xLayer),
          onToggle: onChainToggle,
          onTransferPressed: onTransferPressed,
        ).marginOnly(bottom: 12.h),
        _ChainCard(
          chain: WalletChain.tron,
          address: wallet.tronAddress,
          balances: tronBalances,
          isLoading: isLoading,
          isExpanded: isChainExpanded(WalletChain.tron),
          onToggle: onChainToggle,
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
    required this.isExpanded,
    required this.onToggle,
    required this.onTransferPressed,
  });

  final WalletChain chain;
  final String address;
  final List<ChainBalance> balances;
  final bool isLoading;
  final bool isExpanded;
  final ValueChanged<WalletChain> onToggle;
  final ValueChanged<ChainBalance> onTransferPressed;

  @override
  Widget build(BuildContext context) {
    final hasError = balances.any((balance) => balance.hasError);
    final chainColor = homeChainColor(chain);
    final nativeBalance = _nativeBalanceText();
    final dividerColor = context.appTheme.dividerColor!.withValues(alpha: 0.45);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: homePanelDecoration(context).copyWith(
        border: Border.all(
          color: isExpanded ? chainColor.withValues(alpha: 0.28) : dividerColor,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4.w, color: chainColor),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(13.w, 12.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  expanded: isExpanded,
                  label: chain.name,
                  child: InkWell(
                    onTap: () => onToggle(chain),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Row(
                      children: [
                        Container(
                          width: 38.w,
                          height: 38.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chainColor.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: chainColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            chain.symbol.characters.first,
                            style: TextStyle(
                              color: chainColor,
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
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      chain.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (isLoading && balances.isNotEmpty)
                                    _ChainStatusDot(
                                      color: chainColor,
                                    ).marginOnly(left: 6.w),
                                  if (hasError)
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 15.w,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ).marginOnly(left: 5.w),
                                ],
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                _shortAddress(address),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.56),
                                  fontSize: 10.5.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        _ChainSummaryPill(
                          count: balances.length,
                          amount: nativeBalance,
                          symbol: chain.symbol,
                          color: chainColor,
                          isLoading: isLoading && balances.isEmpty,
                        ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 23.w,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: isExpanded
                      ? Column(
                          key: ValueKey('${chain.id}-assets'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10.h),
                            Divider(
                              height: 1.h,
                              thickness: 1,
                              color: dividerColor,
                            ),
                            SizedBox(height: 2.h),
                            ...balances.map(
                              (balance) => _AssetRow(
                                balance: balance,
                                onTransferPressed: onTransferPressed,
                              ),
                            ),
                            if (balances.isEmpty)
                              _EmptyBalancePlaceholder(
                                isLoading: isLoading,
                              ).marginOnly(top: 8.h),
                            if (hasError)
                              Text(
                                S.of(context).balanceLoadFailed,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 11.sp,
                                ),
                              ).marginOnly(top: 8.h),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nativeBalanceText() {
    for (final balance in balances) {
      if (balance.isNative) {
        return balance.amount;
      }
    }
    return '--';
  }

  String _shortAddress(String value) {
    if (value.length <= 16) {
      return value;
    }
    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }
}

class _ChainStatusDot extends StatelessWidget {
  const _ChainStatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10.w,
      height: 10.w,
      child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
    );
  }
}

class _ChainSummaryPill extends StatelessWidget {
  const _ChainSummaryPill({
    required this.count,
    required this.amount,
    required this.symbol,
    required this.color,
    required this.isLoading,
  });

  final int count;
  final String amount;
  final String symbol;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 112.w, minHeight: 38.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: isLoading
          ? SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$amount $symbol',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        isLoading ? S.of(context).loading : '--',
        style: TextStyle(
          fontSize: 12.sp,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
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
            width: 32.w,
            height: 32.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: assetColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              balance.symbol.characters.first,
              style: TextStyle(
                color: assetColor,
                fontSize: 12.sp,
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
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  balance.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.54),
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
                constraints: BoxConstraints(maxWidth: 110.w),
                child: Text(
                  '${balance.amount} ${balance.symbol}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: S.of(context).transfer,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tight(Size(40.w, 40.w)),
                  onPressed: () => onTransferPressed(balance),
                  icon: Container(
                    width: 32.w,
                    height: 32.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.near_me_rounded,
                      size: 18.w,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  tooltip: S.of(context).transfer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
