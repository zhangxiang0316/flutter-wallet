import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:decimal/decimal.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../wallet/models/token_portfolio.dart';
import '../../../wallet/utils/asset_amount_formatter.dart';
import '../../home/view/widgets/home_styles.dart';
import '../controller/token_portfolio_detail_controller.dart';

@GetXRoutePage('/tokenPortfolioDetail')
// ignore: use_key_in_widget_constructors, must_be_immutable
class TokenPortfolioDetailPage
    extends BaseScaffoldPage<TokenPortfolioDetailController> {
  @override
  TokenPortfolioDetailController generateController() {
    return TokenPortfolioDetailController();
  }

  @override
  PreferredSizeWidget? getAppBar(BuildContext context) {
    final dividerColor = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 50.h,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: Get.back,
      ),
      centerTitle: true,
      title: Text(
        S.of(context).tokenDetails,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  @override
  Widget? getBody(BuildContext context) {
    final item = controller.item;
    if (item == null) {
      return Center(child: Text(S.of(context).transactionNoAsset));
    }
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _TokenSummaryCard(item: item),
          SizedBox(height: 16.h),
          Text(
            S.of(context).networkDistribution,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
          ).marginOnly(left: 2.w),
          SizedBox(height: 8.h),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: homePanelDecoration(context),
            child: Column(
              children: item.positions
                  .asMap()
                  .entries
                  .map((entry) {
                    return Column(
                      children: [
                        _NetworkPositionRow(
                          position: entry.value,
                          onTap: () =>
                              controller.openPositionHistory(entry.value),
                        ),
                        if (entry.key != item.positions.length - 1)
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
      ),
    );
  }
}

class _TokenSummaryCard extends StatelessWidget {
  const _TokenSummaryCard({required this.item});

  final TokenPortfolioItem item;

  @override
  Widget build(BuildContext context) {
    final color = homeAssetColor(context, item.symbol);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: homePanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  item.symbol.characters.first,
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
                      item.symbol,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: homeSubTextColor(context),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                S.of(context).tokenNetworkCount(item.positions.length),
                style: TextStyle(
                  color: homeSubTextColor(context),
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Text(
            '${formatAssetAmount(item.totalAmount.toString())} ${item.symbol}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5.h),
          Text(
            _usdText(item.totalUsdValue),
            style: TextStyle(
              color: homeSubTextColor(context),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.hasPartialError)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 14.h),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                S.of(context).partialNetworkError,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkPositionRow extends StatelessWidget {
  const _NetworkPositionRow({required this.position, required this.onTap});

  final TokenChainPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chainColor = homeChainColor(context, position.chain);
    final balance = position.balance;
    return Semantics(
      button: true,
      label: '${position.chain.name}, ${balance.amount} ${balance.symbol}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 10.w, 12.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: chainColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Text(
                  position.chain.symbol.characters.first,
                  style: TextStyle(
                    color: chainColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.chain.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      balance.hasError
                          ? S.of(context).balanceLoadFailed
                          : balance.isNative
                          ? S.of(context).nativeAsset
                          : S.of(context).tokenContractAsset,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: balance.hasError
                            ? Theme.of(context).colorScheme.error
                            : homeSubTextColor(context),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatAssetAmount(balance.amount)} ${balance.symbol}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _usdText(position.usdValue),
                    style: TextStyle(
                      color: homeSubTextColor(context),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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

String _usdText(Decimal? value) {
  if (value == null) return '--';
  return '\$${value.toStringAsFixed(2)}';
}
