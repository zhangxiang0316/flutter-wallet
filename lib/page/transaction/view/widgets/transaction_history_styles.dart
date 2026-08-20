import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../wallet/models/wallet_chain.dart';

/// 交易记录页面通用面板样式。
BoxDecoration transactionPanelDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(8.r),
    border: Border.all(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
    ),
  );
}

/// 获取链或币种在交易记录页中的主色。
Color transactionChainColor(WalletChainRef chain) {
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
    case WalletChain.polygon:
      return const Color(0xFF8247E5);
    case WalletChain.avalanche:
      return const Color(0xFFE84142);
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

/// 压缩长地址或交易哈希。
String shortTransactionText(String value, {int head = 8, int tail = 6}) {
  final trimmed = value.trim();
  if (trimmed.length <= head + tail + 3) {
    return trimmed;
  }
  return '${trimmed.substring(0, head)}...${trimmed.substring(trimmed.length - tail)}';
}
