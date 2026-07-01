import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../controller/transaction_history_controller.dart';
import 'widgets/transaction_asset_header.dart';
import 'widgets/transaction_empty_state.dart';
import 'widgets/transaction_record_tile.dart';

@GetXRoutePage('/transactionHistory')
/// 交易记录页面。
///
/// 首页点击某个币种后进入本页，展示当前钱包、当前链、当前币种的交易记录。
// ignore: use_key_in_widget_constructors, must_be_immutable
class TransactionHistoryPage
    extends BaseScaffoldPage<TransactionHistoryController> {
  /// 创建交易记录控制器。
  @override
  TransactionHistoryController generateController() {
    return TransactionHistoryController();
  }

  /// 顶部导航栏。
  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
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
        S.of(context!).transactionHistory,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context!).refreshBalance,
          onPressed: controller.isLoading ? null : controller.loadRecords,
          icon: Icon(Icons.refresh_rounded, size: 20.w),
        ).marginOnly(right: 4.w),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context!).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context!).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  /// 页面主体。
  @override
  Widget? getBody() {
    final args = controller.arguments;
    if (args == null) {
      return TransactionEmptyState(message: S.of(context!).transactionNoAsset);
    }

    return ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: RefreshIndicator(
        backgroundColor: Theme.of(context!).cardColor,
        color: Theme.of(context!).colorScheme.primary,
        onRefresh: controller.loadRecords,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
          itemCount: _historyItemCount(),
          itemBuilder: (context, index) => _buildHistoryItem(index),
        ),
      ),
    );
  }

  int _historyItemCount() {
    if (controller.records.isEmpty) return 3;
    return controller.records.length + 3;
  }

  Widget _buildHistoryItem(int index) {
    final args = controller.arguments;
    if (args == null) {
      return const SizedBox.shrink();
    }
    if (index == 0) {
      return TransactionAssetHeader(asset: args.asset);
    }
    if (index == 1) {
      return SizedBox(height: 12.h);
    }

    if (controller.records.isEmpty) {
      if (controller.isLoading) {
        return TransactionEmptyState.loading(message: S.of(context!).loading);
      }
      if (controller.errorMessage.isNotEmpty) {
        return TransactionEmptyState(
          message: controller.errorMessage,
          actionLabel: S.of(context!).openBlockExplorer,
          onAction: controller.openBlockExplorer,
        );
      }
      if (controller.hasMore) {
        return TransactionEmptyState(
          message: S.of(context!).transactionHistoryExplorerHint,
          actionLabel: S.of(context!).transactionLoadMore,
          onAction: controller.loadMoreRecords,
        );
      }
      return TransactionEmptyState(
        message: S.of(context!).transactionHistoryExplorerHint,
        actionLabel: S.of(context!).openBlockExplorer,
        onAction: controller.openBlockExplorer,
      );
    }

    final recordIndex = index - 2;
    if (recordIndex >= controller.records.length) {
      return _buildPaginationFooter();
    }

    final record = controller.records[recordIndex];
    return TransactionRecordTile(
      record: record,
      onTap: () => controller.openRecordDetail(record),
      onCopyHash: () => controller.copyHash(record),
      onRefreshStatus: () => controller.refreshRecordStatus(record),
      onOpenExplorer: () => controller.openTransactionExplorer(record),
    ).marginOnly(bottom: 10.h);
  }

  Widget _buildPaginationFooter() {
    final colorScheme = Theme.of(context!).colorScheme;
    if (controller.isLoading || controller.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
        child: Center(
          child: SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (controller.hasMore) {
      return Padding(
        padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
        child: Center(
          child: TextButton.icon(
            onPressed: controller.loadMoreRecords,
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.w),
            label: Text(S.of(context!).transactionLoadMore),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              minimumSize: Size(0, 34.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              textStyle: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 2.h),
      child: Center(
        child: Text(
          S.of(context!).transactionNoMoreRecords,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.42),
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
