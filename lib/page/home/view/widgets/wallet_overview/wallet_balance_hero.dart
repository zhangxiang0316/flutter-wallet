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
              _WalletSwitcherButton(
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

/// Hero 卡片左上角的钱包切换入口。
///
/// 通过头像、钱包名称和切换提示建立清晰的信息层级，点击后打开钱包切换弹窗。
class _WalletSwitcherButton extends StatefulWidget {
  const _WalletSwitcherButton({
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
  State<_WalletSwitcherButton> createState() => _WalletSwitcherButtonState();
}

class _WalletSwitcherButtonState extends State<_WalletSwitcherButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // 只有存在钱包列表时才允许打开切换弹窗。
    final canOpen = widget.wallets.isNotEmpty;
    return Semantics(
      button: canOpen,
      enabled: canOpen,
      label: S.of(context).switchWallet,
      child: Listener(
        onPointerDown: canOpen ? (_) => setState(() => _pressed = true) : null,
        onPointerCancel: canOpen
            ? (_) => setState(() => _pressed = false)
            : null,
        onPointerUp: canOpen ? (_) => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(maxWidth: 232.w, minHeight: 46.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: _pressed ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: _pressed ? 0.38 : 0.26),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canOpen
                    ? () => _showWalletPicker(
                        context: context,
                        wallet: widget.wallet,
                        wallets: widget.wallets,
                        onWalletSelected: widget.onWalletSelected,
                        onWalletRemoved: widget.onWalletRemoved,
                        onAddWallet: widget.onAddWallet,
                      )
                    : null,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(6.w, 5.h, 8.w, 5.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WalletAvatar(
                        wallet: widget.wallet,
                        selected: true,
                        onDark: true,
                        size: 34,
                      ),
                      SizedBox(width: 9.w),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.wallet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              S.of(context).switchWallet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w600,
                                height: 1,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canOpen) ...[
                        SizedBox(width: 10.w),
                        Container(
                          width: 28.w,
                          height: 28.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 17.w,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
