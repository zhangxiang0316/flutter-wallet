import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../controller/transaction_detail_controller.dart';
import 'widgets/transaction_history_styles.dart';

@GetXRoutePage('/transactionDetail')
/// 交易详情页。
// ignore: use_key_in_widget_constructors, must_be_immutable
class TransactionDetailPage
    extends BaseScaffoldPage<TransactionDetailController> {
  @override
  TransactionDetailController generateController() {
    return TransactionDetailController();
  }

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
        S.of(context!).transactionDetail,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
      ),
      actions: [
        IconButton(
          tooltip: S.of(context!).openBlockExplorer,
          onPressed: controller.openTransactionExplorer,
          icon: Icon(Icons.open_in_browser_rounded, size: 20.w),
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

  @override
  Widget? getBody() {
    final record = controller.record;
    if (record == null) {
      return Center(
        child: Text(
          S.of(context!).transactionNoAsset,
          style: TextStyle(fontSize: 13.sp),
        ),
      );
    }
    return ColoredBox(
      color: Theme.of(context!).brightness == Brightness.dark
          ? Theme.of(context!).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
        children: [
          _TransactionDetailHeader(record: record),
          SizedBox(height: 12.h),
          _DetailSection(
            title: S.of(context!).transactionOverview,
            children: [
              _DetailRow(
                label: S.of(context!).transactionStatus,
                value: _statusText(context!, record.status),
                valueColor: _statusColor(context!, record.status),
              ),
              _DetailRow(
                label: S.of(context!).transactionDirection,
                value: _directionText(context!, record.direction),
              ),
              _DetailRow(
                label: S.of(context!).transactionAmount,
                value:
                    '${_amountPrefix(record)}${record.amount} '
                    '${record.symbol}',
                valueColor: _directionColor(context!, record.direction),
              ),
              if (record.feeAmount?.isNotEmpty ?? false)
                _DetailRow(
                  label: S.of(context!).networkFee,
                  value: '${record.feeAmount} ${record.feeSymbol ?? ''}'.trim(),
                ),
              _DetailRow(
                label: S.of(context!).transactionSource,
                value: _sourceText(context!, record.source),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _DetailSection(
            title: S.of(context!).transactionAddresses,
            children: [
              _DetailRow(
                label: S.of(context!).transactionFrom,
                value: record.fromAddress,
                copyable: true,
                onCopy: () => controller.copyText(record.fromAddress),
              ),
              _DetailRow(
                label: S.of(context!).transactionTo,
                value: record.toAddress,
                copyable: true,
                onCopy: () => controller.copyText(record.toAddress),
              ),
              _DetailRow(
                label: S.of(context!).transactionWalletAddress,
                value: record.walletAddress,
                copyable: true,
                onCopy: () => controller.copyText(record.walletAddress),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _DetailSection(
            title: S.of(context!).transactionChainInfo,
            children: [
              _DetailRow(
                label: S.of(context!).network,
                value: record.chainName,
              ),
              _DetailRow(label: S.of(context!).asset, value: record.assetName),
              if (record.contractAddress?.isNotEmpty ?? false)
                _DetailRow(
                  label: S.of(context!).contractAddress,
                  value: record.contractAddress!,
                  copyable: true,
                  onCopy: () => controller.copyText(record.contractAddress!),
                ),
              _DetailRow(
                label: S.of(context!).blockNumber,
                value: record.blockNumber?.toString() ?? '-',
              ),
              _DetailRow(
                label: S.of(context!).transactionTime,
                value: _formattedTime(context!, record.timestamp),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _DetailSection(
            title: S.of(context!).transactionHash,
            children: [
              _DetailRow(
                label: S.of(context!).transactionHash,
                value: record.txHash,
                copyable: true,
                onCopy: () => controller.copyText(record.txHash),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          FilledButton.icon(
            onPressed: controller.openTransactionExplorer,
            icon: const Icon(Icons.open_in_browser_rounded),
            label: Text(S.of(context!).openBlockExplorer),
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailHeader extends StatelessWidget {
  const _TransactionDetailHeader({required this.record});

  final WalletTransactionRecord record;

  @override
  Widget build(BuildContext context) {
    final directionColor = _directionColor(context, record.direction);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: transactionPanelDecoration(context),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: directionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              _directionIcon(record.direction),
              color: directionColor,
              size: 25.w,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            '${_amountPrefix(record)}${record.amount} ${record.symbol}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: directionColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${record.chainName} · ${_directionText(context, record.direction)}',
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
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: transactionPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96.w,
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.52),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: valueColor ?? colorScheme.onSurface,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          if (copyable) ...[
            SizedBox(width: 6.w),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tight(Size(30.w, 30.w)),
              padding: EdgeInsets.zero,
              tooltip: S.of(context).copied,
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, size: 16.w),
            ),
          ],
        ],
      ),
    );
  }
}

String _amountPrefix(WalletTransactionRecord record) {
  return switch (record.direction) {
    WalletTransactionDirection.incoming => '+',
    WalletTransactionDirection.outgoing => '-',
    WalletTransactionDirection.selfTransfer => '',
    WalletTransactionDirection.unknown => '',
  };
}

IconData _directionIcon(WalletTransactionDirection direction) {
  return switch (direction) {
    WalletTransactionDirection.incoming => Icons.south_west_rounded,
    WalletTransactionDirection.outgoing => Icons.north_east_rounded,
    WalletTransactionDirection.selfTransfer => Icons.swap_horiz_rounded,
    WalletTransactionDirection.unknown => Icons.receipt_long_outlined,
  };
}

Color _directionColor(
  BuildContext context,
  WalletTransactionDirection direction,
) {
  return switch (direction) {
    WalletTransactionDirection.incoming => const Color(0xFF10B981),
    WalletTransactionDirection.outgoing => Theme.of(
      context,
    ).colorScheme.primary,
    WalletTransactionDirection.selfTransfer => const Color(0xFF6366F1),
    WalletTransactionDirection.unknown => Theme.of(
      context,
    ).colorScheme.onSurface,
  };
}

String _directionText(
  BuildContext context,
  WalletTransactionDirection direction,
) {
  final s = S.of(context);
  return switch (direction) {
    WalletTransactionDirection.incoming => s.transactionIncoming,
    WalletTransactionDirection.outgoing => s.transactionOutgoing,
    WalletTransactionDirection.selfTransfer => s.transactionSelfTransfer,
    WalletTransactionDirection.unknown => s.transactionUnknownDirection,
  };
}

Color _statusColor(BuildContext context, WalletTransactionStatus status) {
  return switch (status) {
    WalletTransactionStatus.success => const Color(0xFF10B981),
    WalletTransactionStatus.failed => Theme.of(context).colorScheme.error,
    WalletTransactionStatus.pending => const Color(0xFFF59E0B),
    WalletTransactionStatus.unknown => Theme.of(context).colorScheme.primary,
  };
}

String _statusText(BuildContext context, WalletTransactionStatus status) {
  final s = S.of(context);
  return switch (status) {
    WalletTransactionStatus.success => s.transactionStatusSuccess,
    WalletTransactionStatus.failed => s.transactionStatusFailed,
    WalletTransactionStatus.pending => s.transactionStatusPending,
    WalletTransactionStatus.unknown => s.transactionStatusUnknown,
  };
}

String _sourceText(BuildContext context, WalletTransactionSource source) {
  final s = S.of(context);
  return switch (source) {
    WalletTransactionSource.local => s.transactionSourceLocal,
    WalletTransactionSource.remote => s.transactionSourceRemote,
  };
}

String _formattedTime(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return S.of(context).transactionTimeUnknown;
  final local = timestamp.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
