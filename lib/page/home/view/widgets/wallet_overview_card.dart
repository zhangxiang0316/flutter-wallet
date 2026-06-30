import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'home_styles.dart';

part 'wallet_overview/wallet_balance_hero.dart';
part 'wallet_overview/wallet_panel.dart';
part 'wallet_overview/wallet_picker.dart';
part 'wallet_overview/wallet_action_button.dart';

/// 首页钱包资产概览区域。
///
/// 组合展示总资产卡片、当前钱包切换入口和多链钱包说明。所有钱包切换、
/// 移除、添加动作都通过回调交给首页控制器处理。
class WalletOverviewCard extends StatelessWidget {
  const WalletOverviewCard({
    super.key,
    required this.wallet,
    required this.wallets,
    required this.totalAssetsText,
    required this.onWalletSelected,
    required this.onWalletRemoved,
    required this.onAddWallet,
    required this.onReceivePressed,
    required this.onTransferPressed,
  });

  /// 当前选中的钱包。
  final WalletAccount wallet;

  /// 本地已有钱包列表，用于钱包切换弹窗。
  final List<WalletAccount> wallets;

  /// 已格式化的总资产 USD 文本。
  final String totalAssetsText;

  /// 用户在切换弹窗中选择钱包后的回调。
  final ValueChanged<WalletAccount> onWalletSelected;

  /// 用户确认移除钱包后的回调。
  final Future<void> Function(WalletAccount wallet) onWalletRemoved;

  /// 打开添加钱包流程。
  final VoidCallback onAddWallet;

  /// 打开收款页面。
  final VoidCallback onReceivePressed;

  /// 打开转账页面。
  final VoidCallback onTransferPressed;

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
          onReceivePressed: onReceivePressed,
          onTransferPressed: onTransferPressed,
        ).marginOnly(bottom: 12.h),
        const _PrimaryWalletPanel(),
      ],
    );
  }
}

/// 顶部总资产 Hero 卡片。
///
/// 负责展示当前钱包入口、总资产估值和资产标题；总资产文本变化时使用轻量动画过渡。
