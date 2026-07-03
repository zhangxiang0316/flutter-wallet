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

part 'chain_section/asset_row.dart';
part 'chain_section/chain_card.dart';
part 'chain_section/empty_states.dart';

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
