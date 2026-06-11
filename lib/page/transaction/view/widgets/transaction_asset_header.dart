import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/utils/asset_amount_formatter.dart';
import 'transaction_history_styles.dart';

/// 交易记录页顶部资产摘要。
class TransactionAssetHeader extends StatelessWidget {
  const TransactionAssetHeader({super.key, required this.asset});

  /// 当前正在查看交易记录的资产。
  final ChainBalance asset;

  @override
  Widget build(BuildContext context) {
    final color = transactionChainColor(asset.chainRef);
    final subTextColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.58);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.w),
      decoration: transactionPanelDecoration(context),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              asset.symbol.characters.first.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  '${asset.chainRef.name} · ${asset.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                S.of(context).availableBalance,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                formatAssetAmount(asset.amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
