import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../wallet/models/wallet_chain.dart';

/// 首页卡片和面板的统一背景、圆角和边框样式。
BoxDecoration homePanelDecoration(BuildContext context) {
  // 当前主题色体系，用于兜底边框色。
  final colorScheme = Theme.of(context).colorScheme;

  // 优先取应用主题扩展的分隔线颜色，没有配置时使用 Material outline。
  final dividerColor =
      context.appTheme.dividerColor ??
      colorScheme.outline.withValues(alpha: 0.18);
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(color: dividerColor.withValues(alpha: 0.72)),
  );
}

/// 首页分隔线颜色。
///
/// 优先使用主题扩展里的分隔线配置，深色模式下会降低不透明度。
Color homeDividerColor(BuildContext context) {
  return (context.appTheme.dividerColor ?? const Color(0xFFEBEDF0)).withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 1,
  );
}

/// 首页辅助说明文本颜色。
Color homeSubTextColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
}

/// 首页各条链的品牌识别色。
Color homeChainColor(WalletChainRef chain) {
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
      return const Color(0xFF111827);
    case WalletChain.arbitrum:
      return const Color(0xFF28A0F0);
    case WalletChain.base:
      return const Color(0xFF0052FF);
    case WalletChain.bitcoin:
      return const Color(0xFFF7931A);
    case WalletChain.solana:
      return const Color(0xFF14F195);
    case WalletChain.sui:
      return const Color(0xFF4DA2FF);
    case WalletChain.aptos:
      return const Color(0xFF13B5A4);
    case WalletChain.tron:
      return const Color(0xFFE50914);
    default:
      return const Color(0xFF2563EB);
  }
}

/// 首页各币种头像和标识的颜色。
///
/// 未显式配置的币种回退到当前主题主色，支持用户添加自定义币种后仍有可用配色。
Color homeAssetColor(BuildContext context, String symbol) {
  switch (symbol.toUpperCase()) {
    case 'USDT':
      return const Color(0xFF26A17B);
    case 'USDC':
      return const Color(0xFF2775CA);
    case 'BTCB':
    case 'WBTC':
    case 'CBBTC':
    case 'BTC':
      return const Color(0xFFF7931A);
    case 'ETH':
      return const Color(0xFF627EEA);
    case 'TRX':
      return const Color(0xFFE50914);
    case 'OKB':
      return const Color(0xFF111827);
    case 'ARB':
      return const Color(0xFF28A0F0);
    case 'SOL':
      return const Color(0xFF14F195);
    case 'SUI':
      return const Color(0xFF4DA2FF);
    case 'APT':
      return const Color(0xFF13B5A4);
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
