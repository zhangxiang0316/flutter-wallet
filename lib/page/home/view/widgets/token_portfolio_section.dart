import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:decimal/decimal.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/token_portfolio.dart';
import '../../../../wallet/utils/asset_amount_formatter.dart';
import 'home_styles.dart';

/// 首页按代币聚合的资产区域。
class TokenPortfolioSection extends StatelessWidget {
  const TokenPortfolioSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onTokenTap,
  });

  final List<TokenPortfolioItem> items;
  final bool isLoading;
  final ValueChanged<TokenPortfolioItem> onTokenTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context).tokenAssets,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isLoading && items.isNotEmpty)
                SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: homePanelDecoration(context),
          child: items.isEmpty
              ? _TokenPortfolioEmptyState(isLoading: isLoading)
              : Column(
                  children: items
                      .asMap()
                      .entries
                      .map((entry) {
                        final isLast = entry.key == items.length - 1;
                        return Column(
                          children: [
                            _TokenPortfolioRow(
                              item: entry.value,
                              onTap: () => onTokenTap(entry.value),
                            ),
                            if (!isLast)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 58.w,
                                color: homeDividerColor(context),
                              ),
                          ],
                        );
                      })
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}

class _TokenPortfolioRow extends StatelessWidget {
  const _TokenPortfolioRow({required this.item, required this.onTap});

  final TokenPortfolioItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = homeAssetColor(context, item.symbol);
    final networkText = S.of(context).tokenNetworkCount(item.positions.length);
    return Semantics(
      button: true,
      label: '${item.symbol}, $networkText, ${_usdText(item.totalUsdValue)}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 10.w, 12.h),
          child: Row(
            children: [
              _TokenLogo(
                symbol: item.symbol,
                logoUrl: item.logoUrl,
                color: color,
                size: 36.w,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.symbol,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.hasPartialError)
                          Icon(
                            Icons.error_outline_rounded,
                            size: 14.w,
                            color: Theme.of(context).colorScheme.error,
                          ).marginOnly(left: 5.w),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      networkText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.hasPartialError
                            ? Theme.of(context).colorScheme.error
                            : homeSubTextColor(context),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 130.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatAssetAmount(item.totalAmount.toString())} ${item.symbol}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _usdText(item.totalUsdValue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: homeSubTextColor(context),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 3.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 19.w,
                color: homeSubTextColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenPortfolioEmptyState extends StatelessWidget {
  const _TokenPortfolioEmptyState({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      child: Column(
        children: [
          if (isLoading)
            SizedBox(
              width: 22.w,
              height: 22.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 28.w,
              color: homeSubTextColor(context),
            ),
          SizedBox(height: 10.h),
          Text(
            isLoading ? S.of(context).loading : S.of(context).tokenAssetsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: homeSubTextColor(context),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenLogo extends StatelessWidget {
  const _TokenLogo({
    required this.symbol,
    required this.logoUrl,
    required this.color,
    required this.size,
  });

  final String symbol;
  final String? logoUrl;
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
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: Text(
        symbol.isEmpty ? '?' : symbol.characters.first,
        style: TextStyle(
          color: color,
          fontSize: 13.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    final url = logoUrl?.trim() ?? '';
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9.r),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

String _usdText(Decimal? value) {
  if (value == null) return '--';
  return '\$${value.toStringAsFixed(2)}';
}
