part of '../wallet_overview_card.dart';

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
                      suiAddress: wallet.suiAddress,
                      aptosAddress: wallet.aptosAddress,
                      tronAddress: wallet.tronAddress,
                      bitcoinAddress: wallet.bitcoinAddress,
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
    required this.suiAddress,
    required this.aptosAddress,
    required this.tronAddress,
    required this.bitcoinAddress,
  });

  /// EVM 兼容链地址，当前 BSC、ETH、X Layer、Arbitrum 共用该地址。
  final String bscAddress;

  /// Solana 链地址。
  final String solanaAddress;

  /// Sui 链地址。
  final String suiAddress;

  /// Aptos 链地址。
  final String aptosAddress;

  /// TRON 链地址。
  final String tronAddress;

  /// Bitcoin 链地址。
  final String bitcoinAddress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 地址属于辅助识别信息，使用较弱正文色。
    final textColor = colorScheme.onSurface.withValues(alpha: 0.52);
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8.w) / 2;
        return Wrap(
          spacing: 8.w,
          runSpacing: 3.h,
          children: [
            _WalletAddressText(
              width: itemWidth,
              label: 'EVM',
              address: _shortWalletAddress(bscAddress),
              color: textColor,
            ),
            _WalletAddressText(
              width: itemWidth,
              label: WalletChain.sui.symbol,
              address: _shortWalletAddress(suiAddress),
              color: textColor,
            ),
            _WalletAddressText(
              width: itemWidth,
              label: WalletChain.aptos.symbol,
              address: _shortWalletAddress(aptosAddress),
              color: textColor,
            ),
            _WalletAddressText(
              width: itemWidth,
              label: WalletChain.bitcoin.symbol,
              address: _shortWalletAddress(bitcoinAddress),
              color: textColor,
            ),
            _WalletAddressText(
              width: itemWidth,
              label: WalletChain.solana.symbol,
              address: _shortWalletAddress(solanaAddress),
              color: textColor,
            ),
            _WalletAddressText(
              width: itemWidth,
              label: WalletChain.tron.symbol,
              address: _shortWalletAddress(tronAddress),
              color: textColor,
            ),
          ],
        );
      },
    );
  }
}

/// 单条短地址文本。
class _WalletAddressText extends StatelessWidget {
  const _WalletAddressText({
    required this.label,
    required this.address,
    required this.color,
    required this.width,
  });

  /// 链类型标签，例如 EVM、SOL、TRX。
  final String label;

  /// 已经压缩后的短地址文本。
  final String address;

  /// 地址文本颜色。
  final Color color;

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        '$label $address',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
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
      WalletChain.bitcoin,
      WalletChain.solana,
      WalletChain.sui,
      WalletChain.aptos,
      WalletChain.tron,
    ];
    return SizedBox(
      width: 210.w,
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
      case WalletChain.bitcoin:
        return const Color(0xFFF7931A);
      case WalletChain.solana:
        return const Color(0xFF14F195);
      case WalletChain.sui:
        return const Color(0xFF4DA2FF);
      case WalletChain.aptos:
        return const Color(0xFF13B5A4);
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
      case WalletChain.bitcoin:
        return '₿';
      case WalletChain.solana:
        return 'S';
      case WalletChain.sui:
        return 'S';
      case WalletChain.aptos:
        return 'A';
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
