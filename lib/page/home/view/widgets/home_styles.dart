import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../wallet/models/wallet_chain.dart';

BoxDecoration homePanelDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final dividerColor =
      context.appTheme.dividerColor ??
      colorScheme.outline.withValues(alpha: 0.18);
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(color: dividerColor.withValues(alpha: 0.72)),
  );
}

Color homeDividerColor(BuildContext context) {
  return (context.appTheme.dividerColor ?? const Color(0xFFEBEDF0)).withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 1,
  );
}

Color homeSubTextColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
}

Color homeCellPressColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.035);
}

Color homeChainColor(WalletChain chain) {
  switch (chain) {
    case WalletChain.bsc:
      return const Color(0xFFF0B90B);
    case WalletChain.ethereum:
      return const Color(0xFF627EEA);
    case WalletChain.xLayer:
      return const Color(0xFF111827);
    case WalletChain.solana:
      return const Color(0xFF14F195);
    case WalletChain.tron:
      return const Color(0xFFE50914);
  }
}

Color homeAssetColor(BuildContext context, String symbol) {
  switch (symbol.toUpperCase()) {
    case 'USDT':
      return const Color(0xFF26A17B);
    case 'USDC':
      return const Color(0xFF2775CA);
    case 'BTCB':
    case 'WBTC':
      return const Color(0xFFF7931A);
    case 'ETH':
      return const Color(0xFF627EEA);
    case 'TRX':
      return const Color(0xFFE50914);
    case 'OKB':
      return const Color(0xFF111827);
    case 'SOL':
      return const Color(0xFF14F195);
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
