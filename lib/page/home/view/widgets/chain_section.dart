import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
import '../../../../wallet/utils/asset_amount_formatter.dart';
import 'home_motion.dart';
import 'home_styles.dart';

/// 首页的多链资产区域。
///
/// 输入是一份扁平的 [balances] 列表，本组件负责按链分组，并渲染每条链的
/// 折叠态摘要和展开后的币种明细。
class ChainSection extends StatelessWidget {
  const ChainSection({
    super.key,
    required this.wallet,
    required this.chains,
    required this.balances,
    required this.isLoading,
    required this.stableValueTextFor,
    required this.chainUsdValueTextFor,
    required this.isChainExpanded,
    required this.onChainToggle,
    required this.onAssetTap,
  });

  /// 当前钱包账户，用于读取 EVM、Solana、TRON 等链地址。
  final WalletAccount wallet;

  /// 当前启用的链配置，包含内置链和用户添加的 EVM 链。
  final List<WalletChainConfig> chains;

  /// 控制器加载到的全部可见资产余额，组件内部会按链过滤展示。
  final List<ChainBalance> balances;

  /// 首页余额是否正在刷新，用于展示链级和空态 loading。
  final bool isLoading;

  /// 非稳定币对应的稳定币估值文本，例如 `≈ 12.30 USDT`。
  ///
  /// 稳定币自身不展示额外估值，所以这里可能返回 null。
  final String? Function(ChainBalance balance) stableValueTextFor;

  /// 单条链下所有已定价资产汇总后的 USD 估值文本。
  final String Function(WalletChainConfig chain) chainUsdValueTextFor;

  /// 由控制器保存展开状态，避免刷新余额时丢失用户当前展开的链。
  final bool Function(WalletChainConfig chain) isChainExpanded;

  /// 点击链卡片头部后的展开/收起回调。
  final ValueChanged<WalletChainConfig> onChainToggle;

  /// 点击币种行后的回调，用于进入交易记录等资产详情页面。
  final ValueChanged<ChainBalance> onAssetTap;

  @override
  Widget build(BuildContext context) {
    if (chains.isEmpty) {
      return const _NoAssetResults();
    }

    // 按链枚举动态渲染，EVM 链共用 EVM 地址，非 EVM 链使用各自地址。
    final chainCards = chains
        .map((chain) {
          // 当前链下需要展示的资产余额列表。
          final chainBalances = balances
              .where((balance) => balance.chainId == chain.id)
              .toList();
          return _ChainCard(
            chain: chain,
            address: _addressForChain(chain),
            balances: chainBalances,
            isLoading: isLoading,
            stableValueTextFor: stableValueTextFor,
            usdValueText: chainUsdValueTextFor(chain),
            isExpanded: isChainExpanded(chain),
            onToggle: onChainToggle,
            onAssetTap: onAssetTap,
          );
        })
        .toList(growable: false);
    return Column(
      children: chainCards
          .asMap()
          .entries
          .map(
            (entry) => entry.key == chainCards.length - 1
                ? HomeEntranceItem(
                    key: ValueKey('chain-${chains[entry.key].id}'),
                    delay: Duration(milliseconds: 45 * entry.key),
                    initialOffset: const Offset(0, 0.04),
                    child: entry.value,
                  )
                : HomeEntranceItem(
                    key: ValueKey('chain-${chains[entry.key].id}'),
                    delay: Duration(milliseconds: 45 * entry.key),
                    initialOffset: const Offset(0, 0.04),
                    child: entry.value,
                  ).marginOnly(bottom: 12.h),
          )
          .toList(growable: false),
    );
  }

  /// 获取指定链在当前钱包里的展示地址。
  String _addressForChain(WalletChainConfig chain) {
    if (chain.isEvm) {
      return wallet.bscAddress;
    }
    switch (chain.builtinChain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
      case WalletChain.arbitrum:
        return wallet.bscAddress;
      case WalletChain.solana:
        return wallet.solanaAddress;
      case WalletChain.tron:
        return wallet.tronAddress;
      case null:
        return wallet.bscAddress;
    }
  }
}

class _NoAssetResults extends StatelessWidget {
  const _NoAssetResults();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: homePanelDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.manage_search_rounded,
            size: 30.w,
            color: colorScheme.primary,
          ),
          SizedBox(height: 8.h),
          Text(
            S.of(context).assetFilterNoResults,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

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
    // 当前链是否存在任意余额查询错误。
    final hasError = balances.any((balance) => balance.hasError);

    // 当前链用于头像、边框和 loading 的品牌色。
    final chainColor = homeChainColor(chain);

    // 当前主题下的列表分隔线颜色。
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
            Semantics(
              // 链卡片头部是展开/收起开关。
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
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                // 展开/收起时只做高度和透明度变化，避免列表内容突然跳动。
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
                        Divider(height: 1.h, thickness: 1, color: dividerColor),
                        ...balances.asMap().entries.map(
                          (entry) => HomeEntranceItem(
                            key: ValueKey(
                              '${chain.id}-${entry.value.symbol}-${entry.key}',
                            ),
                            delay: Duration(milliseconds: 26 * entry.key),
                            duration: const Duration(milliseconds: 260),
                            initialOffset: const Offset(0.03, 0),
                            child: _AssetRow(
                              balance: entry.value,
                              // 非稳定币会展示按当前价格换算的稳定币估值。
                              stableValueText: stableValueTextFor(entry.value),
                              onTap: () => onAssetTap(entry.value),
                            ),
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
    );
  }

  /// 将链地址压缩成首页列表可读的短地址。
  String _shortAddress(String value) {
    if (value.length <= 16) {
      return value;
    }
    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }
}

/// 已有余额数据时的小 loading 指示器。
class _ChainStatusDot extends StatelessWidget {
  const _ChainStatusDot({required this.color});

  /// loading 指示器颜色，跟随当前链品牌色。
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

  /// 已格式化的当前链 USD 估值文本。
  final String usdValueText;

  /// loading 指示器颜色，跟随当前链品牌色。
  final Color color;

  /// true 时右侧摘要区域展示 loading。
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

/// 首次加载或链下无资产数据时的占位状态。
class _EmptyBalancePlaceholder extends StatelessWidget {
  const _EmptyBalancePlaceholder({required this.isLoading});

  /// true 表示仍在加载，false 表示加载完成但没有可展示资产。
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

/// 单个币种的资产行。
///
/// 左侧展示币种标识和名称，右侧展示余额和非稳定币估值。
class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.balance,
    required this.stableValueText,
    required this.onTap,
  });

  /// 当前资产余额数据。
  final ChainBalance balance;

  /// 非稳定币换算成稳定币后的展示文本；稳定币为 null。
  final String? stableValueText;

  /// 点击资产行后的回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 当前币种头像和标识使用的颜色。
    final assetColor = homeAssetColor(context, balance.symbol);

    return Semantics(
      button: true,
      label: '${balance.symbol} ${S.of(context).transactionHistory}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            children: [
              _AssetLogo(
                balance: balance,
                color: assetColor,
                size: 32.w,
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
                        color: homeSubTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 124.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatAssetAmount(balance.amount),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (stableValueText != null)
                      Text(
                        stableValueText!,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: homeSubTextColor(context),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ).marginOnly(top: 3.h),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 18.w,
                color: homeSubTextColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({
    required this.balance,
    required this.color,
    required this.size,
  });

  final ChainBalance balance;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        balance.symbol.trim().isEmpty ? '?' : balance.symbol.characters.first,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final logoUrl = balance.logoUrl?.trim() ?? '';
    if (logoUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
