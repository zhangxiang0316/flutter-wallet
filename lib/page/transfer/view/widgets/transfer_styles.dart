import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../wallet/models/wallet_chain.dart';

BoxDecoration transferPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: context.appTheme.dividerColor!.withValues(alpha: 0.45),
    ),
    boxShadow: [
      BoxShadow(
        color: context.appTheme.cardShadowColor ?? Colors.transparent,
        blurRadius: 14.r,
        offset: Offset(0, 6.h),
      ),
    ],
  );
}

InputDecoration transferInputDecoration(
  BuildContext context, {
  required String label,
  required IconData icon,
  String? hint,
  String? suffix,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: colorScheme.onSurface.withValues(alpha: 0.035),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(
        color: context.appTheme.dividerColor!.withValues(alpha: 0.58),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(
        color: context.appTheme.dividerColor!.withValues(alpha: 0.58),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
    ),
  );
}

Color transferChainColor(WalletChain chain) {
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

Color transferAssetColor(BuildContext context, String symbol) {
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
