import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_account.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'home_styles.dart';

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
class _BalanceHeroCard extends StatefulWidget {
  const _BalanceHeroCard({
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

  /// 本地已有钱包列表，用于传递给切换弹窗。
  final List<WalletAccount> wallets;

  /// 已格式化的总资产 USD 文本。
  final String totalAssetsText;

  /// 用户从切换弹窗选择钱包后的回调。
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
  State<_BalanceHeroCard> createState() => _BalanceHeroCardState();
}

class _BalanceHeroCardState extends State<_BalanceHeroCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Hero 卡片背景高光的轻量循环动画。
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // ✅ 根据应用生命周期控制动画
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_glowController.isAnimating) {
          _glowController.repeat(reverse: true);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _glowController.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用主题主色参与渐变，保证 Hero 卡片能跟随主题变化。
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
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Positioned(
                right: -48.w + (_glowController.value * 16.w),
                top: -42.h,
                child: child!,
              );
            },
            child: Container(
              width: 168.w,
              height: 168.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
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
                wallet: widget.wallet,
                wallets: widget.wallets,
                onWalletSelected: widget.onWalletSelected,
                onWalletRemoved: widget.onWalletRemoved,
                onAddWallet: widget.onAddWallet,
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
                    key: ValueKey(widget.totalAssetsText),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.totalAssetsText,
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
              SizedBox(height: 18.h),
              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeroActionButton(
                      icon: Icons.qr_code_2_rounded,
                      label: S.of(context).receive,
                      onPressed: widget.onReceivePressed,
                    ),
                    SizedBox(width: 10.w),
                    _HeroActionButton(
                      icon: Icons.near_me_rounded,
                      label: S.of(context).transfer,
                      onPressed: widget.onTransferPressed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hero 卡片左上角的钱包名称胶囊入口。
///
/// 点击后打开钱包切换底部弹窗，同时提供添加钱包和移除钱包入口。
class _WalletNamePill extends StatelessWidget {
  const _WalletNamePill({
    required this.wallet,
    required this.wallets,
    required this.onWalletSelected,
    required this.onWalletRemoved,
    required this.onAddWallet,
  });

  /// 当前选中的钱包。
  final WalletAccount wallet;

  /// 本地已有钱包列表，用于判断是否可以打开切换弹窗。
  final List<WalletAccount> wallets;

  /// 用户从切换弹窗选择钱包后的回调。
  final ValueChanged<WalletAccount> onWalletSelected;

  /// 用户确认移除钱包后的回调。
  final Future<void> Function(WalletAccount wallet) onWalletRemoved;

  /// 打开添加钱包流程。
  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    // 只有存在钱包列表时才允许打开切换弹窗。
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

/// Hero 卡片上的快捷操作按钮。
class _HeroActionButton extends StatefulWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// 按钮图标。
  final IconData icon;

  /// 按钮文案。
  final String label;

  /// 点击后的业务回调。
  final VoidCallback onPressed;

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  /// 当前按钮是否处于按压状态。
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerCancel: (_) => setState(() => _pressed = false),
        onPointerUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.white.withValues(alpha: _pressed ? 0.22 : 0.16),
            borderRadius: BorderRadius.circular(999.r),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(999.r),
              child: Container(
                height: 38.h,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 17.w),
                    SizedBox(width: 7.w),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 当前钱包支持的多链能力说明面板。
///
/// 用重叠链标识强调这是一个多链钱包，避免在首页重复展示各链地址。
class _PrimaryWalletPanel extends StatelessWidget {
  const _PrimaryWalletPanel();

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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 钱包切换弹窗中的单个钱包行。
///
/// 展示钱包名称、各链短地址、选中态和移除按钮。
class _WalletOptionRow extends StatelessWidget {
  const _WalletOptionRow({
    required this.wallet,
    required this.selected,
    required this.onTap,
    required this.onRemovePressed,
  });

  /// 当前行对应的钱包。
  final WalletAccount wallet;

  /// 当前行是否为首页正在使用的钱包。
  final bool selected;

  /// 点击钱包行后的选择回调。
  final VoidCallback onTap;

  /// 点击移除按钮后的回调。
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
                      solanaAddress: wallet.solanaAddress,
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

/// 钱包头像。
///
/// 使用钱包名称首字母作为轻量标识；在深色 Hero 卡片和普通列表中会使用不同配色。
class _WalletAvatar extends StatelessWidget {
  const _WalletAvatar({
    required this.wallet,
    required this.selected,
    this.size = 28,
    this.onDark = false,
  });

  /// 用于提取头像首字母的钱包。
  final WalletAccount wallet;

  /// 是否处于选中态，选中态会使用强调色。
  final bool selected;

  /// 头像尺寸，单位会通过 ScreenUtil 转换。
  final double size;

  /// 是否展示在深色背景上。
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 深色背景或选中态使用白色文字，否则使用主题正文色。
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

/// 钱包在不同链上的短地址集合。
///
/// 钱包切换弹窗里使用该组件辅助识别具体账户。
class _WalletAddressLine extends StatelessWidget {
  const _WalletAddressLine({
    required this.bscAddress,
    required this.solanaAddress,
    required this.tronAddress,
  });

  /// EVM 兼容链地址，当前 BSC、ETH、X Layer、Arbitrum 共用该地址。
  final String bscAddress;

  /// Solana 链地址。
  final String solanaAddress;

  /// TRON 链地址。
  final String tronAddress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 地址属于辅助识别信息，使用较弱正文色。
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
            label: WalletChain.solana.symbol,
            address: _shortWalletAddress(solanaAddress),
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

/// 单条短地址文本。
class _WalletAddressText extends StatelessWidget {
  const _WalletAddressText({
    required this.label,
    required this.address,
    required this.color,
  });

  /// 链类型标签，例如 EVM、SOL、TRX。
  final String label;

  /// 已经压缩后的短地址文本。
  final String address;

  /// 地址文本颜色。
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

/// 首页多链钱包能力的重叠链标识。
class _ChainOverlapTicker extends StatelessWidget {
  const _ChainOverlapTicker();

  @override
  Widget build(BuildContext context) {
    // 首页当前支持展示的钱包链标识。
    final chains = [
      WalletChain.bsc,
      WalletChain.ethereum,
      WalletChain.xLayer,
      WalletChain.arbitrum,
      WalletChain.solana,
      WalletChain.tron,
    ];
    return SizedBox(
      width: 144.w,
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

/// 单个链的圆形缩写标识。
class _ChainCircle extends StatelessWidget {
  const _ChainCircle({required this.chain});

  /// 当前圆形标识对应的链。
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
      case WalletChain.arbitrum:
        return const Color(0xFF28A0F0);
      case WalletChain.solana:
        return const Color(0xFF14F195);
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
      case WalletChain.arbitrum:
        return 'A';
      case WalletChain.solana:
        return 'S';
      case WalletChain.tron:
        return 'T';
    }
  }
}

/// 将地址压缩成前 6 后 4 的展示形式。
String _shortWalletAddress(String address) {
  if (address.length <= 12) {
    return address;
  }
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

/// 从钱包名称提取头像首字母。
String _walletInitial(WalletAccount wallet) {
  final name = wallet.name.trim();
  if (name.isNotEmpty) {
    return name.characters.first.toUpperCase();
  }
  return 'W';
}

/// 钱包切换弹窗头部。
///
/// 左侧展示标题，右侧提供添加钱包和关闭弹窗按钮。
class _WalletPickerHeader extends StatelessWidget {
  const _WalletPickerHeader({required this.onAddWallet});

  /// 点击右侧加号后的添加钱包入口。
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

/// 钱包切换弹窗顶部的当前钱包预览。
class _CurrentWalletPreview extends StatelessWidget {
  const _CurrentWalletPreview({required this.wallet});

  /// 当前首页正在使用的钱包。
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
                  solanaAddress: wallet.solanaAddress,
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

/// 打开钱包切换底部弹窗。
///
/// 弹窗内部只负责选择、添加和移除确认的 UI 编排，实际钱包状态更新由传入回调完成。
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
      // 使用弹窗自身 context 的主题，避免跨 route 后主题引用不一致。
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
                      // 当前列表项对应的钱包账户。
                      final item = wallets[index];
                      return _WalletOptionRow(
                        wallet: item,
                        selected: item.id == wallet.id,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onWalletSelected(item);
                        },
                        onRemovePressed: () async {
                          // 移除钱包属于高风险操作，必须先二次确认。
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

/// 移除钱包前的二次确认弹窗。
Future<bool> _confirmRemoveWallet(
  BuildContext context,
  WalletAccount wallet,
) async {
  // 删除按钮使用错误色，提示这是不可恢复操作。
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
