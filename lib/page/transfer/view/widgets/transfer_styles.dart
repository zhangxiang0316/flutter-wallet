import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/theme/app_theme_extension.dart';
import '../../../../wallet/models/wallet_chain.dart';

/// 转账页面通用面板装饰。
///
/// 统一圆角、边框和阴影，保证 Hero 以外的表单、手续费、结果面板视觉一致。
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

/// 转账页面通用输入框样式。
///
/// 支持标签、图标、占位符和后缀币种，主要用于地址、金额、密码输入框。
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
    labelStyle: TextStyle(fontSize: 12.sp),
    hintStyle: TextStyle(
      fontSize: 12.sp,
      color: colorScheme.onSurface.withValues(alpha: 0.42),
    ),
    suffixStyle: TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface.withValues(alpha: 0.62),
    ),
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

/// 转账页面输入文字统一样式。
TextStyle transferInputTextStyle(BuildContext context) {
  return TextStyle(
    fontSize: 13.sp,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

/// 获取链在转账页面中的强调色。
Color transferChainColor(WalletChainRef chain) {
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
    case WalletChain.bitcoin:
      return const Color(0xFFF7931A);
    case WalletChain.solana:
      return const Color(0xFF14F195);
    case WalletChain.sui:
      return const Color(0xFF4DA2FF);
    case WalletChain.tron:
      return const Color(0xFFE50914);
    default:
      return const Color(0xFF2563EB);
  }
}

/// 获取币种在转账页面中的强调色。
///
/// 常见资产使用固定品牌色，其余资产回退到当前主题主色。
Color transferAssetColor(BuildContext context, String symbol) {
  switch (symbol.toUpperCase()) {
    case 'USDT':
      return const Color(0xFF26A17B);
    case 'USDC':
      return const Color(0xFF2775CA);
    case 'BTCB':
    case 'WBTC':
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
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
