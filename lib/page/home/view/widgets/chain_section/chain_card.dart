part of '../chain_section.dart';

/// 单条链卡片。
///
/// 头部展示链名称、地址和链级 USD 估值；展开后展示该链下每个币种的余额、
/// 估值和转账入口。
class _ChainCard extends StatelessWidget {
  const _ChainCard({
    required this.chain,
    required this.address,
    required this.balances,
    required this.isLoading,
    required this.stableValueTextFor,
    required this.usdValueText,
    required this.isExpanded,
    required this.onToggle,
    required this.onAssetTap,
  });

  /// 当前卡片对应的链。
  final WalletChainConfig chain;

  /// 当前链在钱包中的展示地址。
  final String address;

  /// 当前链下的资产余额列表。
  final List<ChainBalance> balances;

  /// 当前链余额是否处于刷新状态。
  final bool isLoading;

  /// 单个资产换算成稳定币后的估值文本生成器。
  final String? Function(ChainBalance balance) stableValueTextFor;

  /// 当前链所有资产汇总后的 USD 文本。
  final String usdValueText;

  /// 当前链是否处于展开状态。
  final bool isExpanded;

  /// 点击链头部后的展开状态切换回调。
  final ValueChanged<WalletChainConfig> onToggle;

  /// 点击币种行后的回调。
  final ValueChanged<ChainBalance> onAssetTap;

  @override
  Widget build(BuildContext context) {
    final hasError = balances.any((balance) => balance.hasError);
    final chainColor = homeChainColor(chain);
    final dividerColor = homeDividerColor(context);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: homePanelDecoration(context).copyWith(
        border: Border.all(
          color: isExpanded ? chainColor.withValues(alpha: 0.22) : dividerColor,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ChainCardHeader(
              chain: chain,
              address: address,
              balances: balances,
              isLoading: isLoading,
              hasError: hasError,
              usdValueText: usdValueText,
              isExpanded: isExpanded,
              chainColor: chainColor,
              onToggle: onToggle,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isExpanded
                  ? _ChainAssetList(
                      key: ValueKey('${chain.id}-assets'),
                      chain: chain,
                      balances: balances,
                      isLoading: isLoading,
                      hasError: hasError,
                      dividerColor: dividerColor,
                      stableValueTextFor: stableValueTextFor,
                      onAssetTap: onAssetTap,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChainCardHeader extends StatelessWidget {
  const _ChainCardHeader({
    required this.chain,
    required this.address,
    required this.balances,
    required this.isLoading,
    required this.hasError,
    required this.usdValueText,
    required this.isExpanded,
    required this.chainColor,
    required this.onToggle,
  });

  final WalletChainConfig chain;
  final String address;
  final List<ChainBalance> balances;
  final bool isLoading;
  final bool hasError;
  final String usdValueText;
  final bool isExpanded;
  final Color chainColor;
  final ValueChanged<WalletChainConfig> onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: isExpanded,
      label: chain.name,
      child: InkWell(
        onTap: () => onToggle(chain),
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chainColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(8.r),
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
                            color: Theme.of(context).colorScheme.error,
                          ).marginOnly(left: 5.w),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _shortAddress(address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: homeSubTextColor(context),
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              _ChainSummaryPill(
                usdValueText: usdValueText,
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
                  color: homeSubTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortAddress(String value) {
    if (value.length <= 16) {
      return value;
    }
    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }
}

class _ChainAssetList extends StatelessWidget {
  const _ChainAssetList({
    super.key,
    required this.chain,
    required this.balances,
    required this.isLoading,
    required this.hasError,
    required this.dividerColor,
    required this.stableValueTextFor,
    required this.onAssetTap,
  });

  final WalletChainConfig chain;
  final List<ChainBalance> balances;
  final bool isLoading;
  final bool hasError;
  final Color dividerColor;
  final String? Function(ChainBalance balance) stableValueTextFor;
  final ValueChanged<ChainBalance> onAssetTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        Divider(height: 1.h, thickness: 1, color: dividerColor),
        ...balances.asMap().entries.map(
          (entry) => HomeEntranceItem(
            key: ValueKey('${chain.id}-${entry.value.symbol}-${entry.key}'),
            delay: Duration(milliseconds: 26 * entry.key),
            duration: const Duration(milliseconds: 260),
            initialOffset: const Offset(0.03, 0),
            child: _AssetRow(
              balance: entry.value,
              stableValueText: stableValueTextFor(entry.value),
              onTap: () => onAssetTap(entry.value),
            ),
          ),
        ),
        if (balances.isEmpty)
          _EmptyBalancePlaceholder(isLoading: isLoading).marginOnly(top: 8.h),
        if (hasError)
          Text(
            S.of(context).balanceLoadFailed,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 11.sp,
            ),
          ).marginOnly(top: 8.h),
      ],
    );
  }
}

/// 已有余额数据时的小 loading 指示器。
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

/// 链卡片右侧的折叠态摘要，只展示当前链的 USD 汇总估值。
class _ChainSummaryPill extends StatelessWidget {
  const _ChainSummaryPill({
    required this.usdValueText,
    required this.color,
    required this.isLoading,
  });

  final String usdValueText;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 112.w, minHeight: 38.h),
      alignment: Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      child: isLoading
          ? SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Text(
              usdValueText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
