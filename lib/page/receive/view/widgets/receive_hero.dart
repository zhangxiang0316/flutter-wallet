import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_asset.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'receive_styles.dart';

/// 收款页顶部摘要卡片。
///
/// 用于提示当前选择的币种和网络，让用户在展示二维码前确认收款上下文。
class ReceiveHero extends StatelessWidget {
  const ReceiveHero({super.key, required this.asset, required this.chain});

  /// 当前收款币种。
  final WalletAsset asset;

  /// 当前收款网络。
  final WalletChainConfig chain;

  @override
  Widget build(BuildContext context) {
    final color = receiveChainColor(context, chain);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: receiveDividerColor(context)),
      ),
      child: Row(
        children: [
          ReceiveAssetAvatar(symbol: asset.symbol, color: color, size: 42),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).receiveAsset(asset.symbol),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  chain.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
