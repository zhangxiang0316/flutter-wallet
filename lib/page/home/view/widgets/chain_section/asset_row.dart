part of '../chain_section.dart';

/// 单个币种的资产行。
///
/// 左侧展示币种标识和名称，右侧展示余额和非稳定币估值。
class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.balance,
    required this.stableValueText,
    required this.onTap,
  });

  /// 当前资产余额数据。
  final ChainBalance balance;

  /// 非稳定币换算成稳定币后的展示文本；稳定币为 null。
  final String? stableValueText;

  /// 点击资产行后的回调。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assetColor = homeAssetColor(context, balance.symbol);

    return Semantics(
      button: true,
      label: '${balance.symbol} ${S.of(context).transactionHistory}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            children: [
              _AssetLogo(
                balance: balance,
                color: assetColor,
                size: 32.w,
              ).marginOnly(right: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.symbol,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      balance.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: homeSubTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 124.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatAssetAmount(balance.amount),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (stableValueText != null)
                      Text(
                        stableValueText!,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: homeSubTextColor(context),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ).marginOnly(top: 3.h),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 18.w,
                color: homeSubTextColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetLogo extends StatelessWidget {
  const _AssetLogo({
    required this.balance,
    required this.color,
    required this.size,
  });

  final ChainBalance balance;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        balance.symbol.trim().isEmpty ? '?' : balance.symbol.characters.first,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final logoUrl = balance.logoUrl?.trim() ?? '';
    if (logoUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
