import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../wallet/models/wallet_chain.dart';
import '../../../../widget/chain_presentation_scope.dart';

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
Color transactionChainColor(BuildContext context, WalletChainRef chain) {
  final configColor = chain is WalletChainConfig ? chain.colorValue : null;
  if (configColor != null) {
    return Color(configColor);
  }
  final presentation = ChainPresentationScope.of(context).presentation(chain);
  return Color(presentation.colorValue);
}

/// 压缩长地址或交易哈希。
String shortTransactionText(String value, {int head = 8, int tail = 6}) {
  final trimmed = value.trim();
  if (trimmed.length <= head + tail + 3) {
    return trimmed;
  }
  return '${trimmed.substring(0, head)}...${trimmed.substring(trimmed.length - tail)}';
}
