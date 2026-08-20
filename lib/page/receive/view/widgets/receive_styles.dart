import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../wallet/models/wallet_chain.dart';

/// 收款页通用分隔线颜色。
Color receiveDividerColor(BuildContext context) {
  return Theme.of(context).colorScheme.outline.withValues(alpha: 0.12);
}

/// 获取收款页中每条链的品牌色。
Color receiveChainColor(WalletChainRef chain) {
  final configColor = chain is WalletChainConfig ? chain.colorValue : null;
  if (configColor != null) {
    return Color(configColor);
  }
  switch (chain) {
    case WalletChain.bsc:
      return const Color(0xFFF0B90B);
    case WalletChain.ethereum:
      return const Color(0xFF627EEA);
    case WalletChain.xLayer:
      return const Color(0xFF10B981);
    case WalletChain.arbitrum:
      return const Color(0xFF28A0F0);
    case WalletChain.base:
      return const Color(0xFF0052FF);
    case WalletChain.polygon:
      return const Color(0xFF8247E5);
    case WalletChain.avalanche:
      return const Color(0xFFE84142);
    case WalletChain.bitcoin:
      return const Color(0xFFF7931A);
    case WalletChain.solana:
      return const Color(0xFF7C3AED);
    case WalletChain.sui:
      return const Color(0xFF4DA2FF);
    case WalletChain.aptos:
      return const Color(0xFF13B5A4);
    case WalletChain.tron:
      return const Color(0xFFE11D48);
    default:
      return const Color(0xFF2563EB);
  }
}

/// 获取链在小圆点中的单字母缩写。
String receiveChainLabel(WalletChainRef chain) {
  switch (chain) {
    case WalletChain.bsc:
      return 'B';
    case WalletChain.ethereum:
      return 'E';
    case WalletChain.xLayer:
      return 'O';
    case WalletChain.arbitrum:
      return 'A';
    case WalletChain.base:
      return 'B';
    case WalletChain.polygon:
      return 'P';
    case WalletChain.avalanche:
      return 'V';
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
    default:
      return chain.name.trim().isEmpty
          ? '?'
          : chain.name.characters.first.toUpperCase();
  }
}

/// 收款页通用面板容器。
///
/// 统一白底、圆角、细边框和标题布局。
class ReceivePanel extends StatelessWidget {
  const ReceivePanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  /// 面板标题。
  final String title;

  /// 面板主体内容。
  final Widget child;

  /// 标题右侧的可选附加组件，例如加载状态。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: receiveDividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

/// 币种头像。
///
/// 使用币种首字母和链色生成轻量标识，避免依赖远程图标。
class ReceiveAssetAvatar extends StatelessWidget {
  const ReceiveAssetAvatar({
    super.key,
    required this.symbol,
    required this.color,
    required this.size,
  });

  /// 币种简称。
  final String symbol;

  /// 头像主色。
  final Color color;

  /// 头像尺寸。
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = symbol.trim().isEmpty ? '?' : symbol.characters.first;
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 链选择器中的圆点标识。
class ReceiveChainDot extends StatelessWidget {
  const ReceiveChainDot({
    super.key,
    required this.chain,
    required this.selected,
  });

  /// 对应链。
  final WalletChainRef chain;

  /// 是否为当前选中链。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = receiveChainColor(chain);
    return Container(
      width: 18.w,
      height: 18.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.18 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        receiveChainLabel(chain),
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
