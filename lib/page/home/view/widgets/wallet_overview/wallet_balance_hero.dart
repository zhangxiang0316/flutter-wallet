part of '../wallet_overview_card.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 155.h), // 从 180.h 减少到 155.h
      padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 16.h), // 减少内边距
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  // 深色主题：深紫-深蓝渐变
                  const Color(0xFF6366F1), // Indigo
                  const Color(0xFF8B5CF6), // Purple
                  const Color(0xFF3B82F6), // Blue
                ]
              : [
                  // 浅色主题：亮紫-蓝-青渐变
                  const Color(0xFF8B5CF6), // Purple
                  const Color(0xFF3B82F6), // Blue
                  const Color(0xFF06B6D4), // Cyan
                ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6))
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 玻璃态效果 - 左上角光斑
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Positioned(
                left: -60.w + (_glowController.value * 20.w),
                top: -60.h + (_glowController.value * 10.h),
                child: child!,
              );
            },
            child: Container(
              width: 180.w,
              height: 180.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 玻璃态效果 - 右下角光斑
          Positioned(
            right: -40.w,
            bottom: -40.h,
            child: Container(
              width: 140.w,
              height: 140.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 装饰性钱包图标
          Positioned(
            right: 10.w,
            top: 10.h,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 100.w,
              color: Colors.white.withValues(alpha: 0.08),
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
              SizedBox(height: 18.h), // 从 24.h 减少到 18.h
              // 总资产标签
              Align(
                alignment: Alignment.center,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${S.of(context).totalAssets} (USD)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h), // 从 10.h 减少到 8.h
              // 总资产金额
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
                        fontSize: 36.sp, // 从 42.sp 减少到 36.sp
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.h), // 从 20.h 减少到 16.h
              // 收款/转账按钮
              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModernActionButton(
                      icon: Icons.qr_code_2_rounded,
                      label: S.of(context).receive,
                      onPressed: widget.onReceivePressed,
                    ),
                    SizedBox(width: 12.w),
                    _ModernActionButton(
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
            constraints: BoxConstraints(
              maxWidth: 246.w,
              minHeight: 38.h,
            ), // 从 43.h 减少到 38.h
            padding: EdgeInsets.fromLTRB(5.w, 4.h, 7.w, 4.h), // 减少 padding
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
                  size: 28, // 从 32 减少到 28
                ),
                SizedBox(width: 8.w), // 从 9.w 减少到 8.w
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
                          fontSize: 12.sp, // 从 12.5.sp 减少到 12.sp
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canOpen) ...[
                  SizedBox(width: 6.w), // 从 8.w 减少到 6.w
                  Container(
                    width: 22.w, // 从 24.w 减少到 22.w
                    height: 22.w, // 从 24.w 减少到 22.w
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: colorScheme.onPrimary,
                      size: 16.w, // 从 17.w 减少到 16.w
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
                height: 34.h, // 从 38.h 减少到 34.h
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                ), // 从 14.w 减少到 12.w
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 16.w,
                    ), // 从 17.w 减少到 16.w
                    SizedBox(width: 6.w), // 从 7.w 减少到 6.w
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp, // 从 12.5.sp 减少到 12.sp
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
