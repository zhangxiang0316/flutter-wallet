import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_transaction_record.dart';
import 'transaction_history_styles.dart';

/// 单条交易记录。
class TransactionRecordTile extends StatelessWidget {
  const TransactionRecordTile({
    super.key,
    required this.record,
    required this.onTap,
    required this.onCopyHash,
    this.onRefreshStatus,
    this.onOpenExplorer,
  });

  /// 交易记录数据。
  final WalletTransactionRecord record;

  /// 打开交易详情回调。
  final VoidCallback onTap;

  /// 复制交易哈希回调。
  final VoidCallback onCopyHash;

  final VoidCallback? onRefreshStatus;

  final VoidCallback? onOpenExplorer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final directionColor = _directionColor(context);
    final subTextColor = colorScheme.onSurface.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: transactionPanelDecoration(context),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: directionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      _directionIcon(),
                      color: directionColor,
                      size: 18.w,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _directionText(context),
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _formattedTime(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 10.5.sp,
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
                        '${_amountPrefix()}${record.amount} ${record.symbol}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: directionColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      _StatusPill(status: record.status, source: record.source),
                    ],
                  ),
                ],
              ),
              Divider(
                height: 18.h,
                thickness: 1,
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
              _InfoRow(
                label: S.of(context).transactionHash,
                value: shortTransactionText(record.txHash, head: 10, tail: 8),
                trailing: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: BoxConstraints.tight(Size(30.w, 30.w)),
                  padding: EdgeInsets.zero,
                  tooltip: S.of(context).copyHash,
                  onPressed: onCopyHash,
                  icon: Icon(Icons.copy_rounded, size: 16.w),
                ),
              ),
              SizedBox(height: 7.h),
              _InfoRow(
                label: S.of(context).transactionFrom,
                value: shortTransactionText(record.fromAddress),
              ),
              SizedBox(height: 7.h),
              _InfoRow(
                label: S.of(context).transactionTo,
                value: shortTransactionText(record.toAddress),
              ),
              if (record.feeAmount?.isNotEmpty ?? false) ...[
                SizedBox(height: 7.h),
                _InfoRow(
                  label: S.of(context).networkFee,
                  value: '${record.feeAmount} ${record.feeSymbol ?? ''}'.trim(),
                ),
              ],
              if (_showsStatusActions) ...[
                SizedBox(height: 10.h),
                Row(
                  children: [
                    if (_canRefreshStatus)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRefreshStatus,
                          icon: Icon(Icons.refresh_rounded, size: 16.w),
                          label: Text(S.of(context).transactionRefreshStatus),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(0, 32.h),
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            textStyle: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    if (_canRefreshStatus && onOpenExplorer != null)
                      SizedBox(width: 8.w),
                    if (onOpenExplorer != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOpenExplorer,
                          icon: Icon(Icons.open_in_new_rounded, size: 16.w),
                          label: Text(S.of(context).openBlockExplorer),
                          style: OutlinedButton.styleFrom(
                            minimumSize: Size(0, 32.h),
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            textStyle: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _showsStatusActions {
    final supportsActions =
        record.status == WalletTransactionStatus.pending ||
        record.status == WalletTransactionStatus.failed;
    return supportsActions && (_canRefreshStatus || onOpenExplorer != null);
  }

  bool get _canRefreshStatus {
    return record.source == WalletTransactionSource.local &&
        record.status == WalletTransactionStatus.pending &&
        onRefreshStatus != null;
  }

  String _amountPrefix() {
    return switch (record.direction) {
      WalletTransactionDirection.incoming => '+',
      WalletTransactionDirection.outgoing => '-',
      WalletTransactionDirection.selfTransfer => '',
      WalletTransactionDirection.unknown => '',
    };
  }

  IconData _directionIcon() {
    return switch (record.direction) {
      WalletTransactionDirection.incoming => Icons.south_west_rounded,
      WalletTransactionDirection.outgoing => Icons.north_east_rounded,
      WalletTransactionDirection.selfTransfer => Icons.swap_horiz_rounded,
      WalletTransactionDirection.unknown => Icons.receipt_long_outlined,
    };
  }

  Color _directionColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (record.direction) {
      WalletTransactionDirection.incoming => const Color(0xFF10B981),
      WalletTransactionDirection.outgoing => colorScheme.primary,
      WalletTransactionDirection.selfTransfer => const Color(0xFF6366F1),
      WalletTransactionDirection.unknown => colorScheme.onSurface,
    };
  }

  String _directionText(BuildContext context) {
    final s = S.of(context);
    return switch (record.direction) {
      WalletTransactionDirection.incoming => s.transactionIncoming,
      WalletTransactionDirection.outgoing => s.transactionOutgoing,
      WalletTransactionDirection.selfTransfer => s.transactionSelfTransfer,
      WalletTransactionDirection.unknown => s.transactionUnknownDirection,
    };
  }

  String _formattedTime(BuildContext context) {
    final timestamp = record.timestamp;
    if (timestamp == null) {
      return S.of(context).transactionTimeUnknown;
    }
    final local = timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.source});

  final WalletTransactionStatus status;
  final WalletTransactionSource source;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        '${_statusText(context)} · ${_sourceText(context)}',
        style: TextStyle(
          color: color,
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    return switch (status) {
      WalletTransactionStatus.success => const Color(0xFF10B981),
      WalletTransactionStatus.failed => Theme.of(context).colorScheme.error,
      WalletTransactionStatus.pending => const Color(0xFFF59E0B),
      WalletTransactionStatus.unknown => Theme.of(context).colorScheme.primary,
    };
  }

  String _statusText(BuildContext context) {
    final s = S.of(context);
    return switch (status) {
      WalletTransactionStatus.success => s.transactionStatusSuccess,
      WalletTransactionStatus.failed => s.transactionStatusFailed,
      WalletTransactionStatus.pending => s.transactionStatusPending,
      WalletTransactionStatus.unknown => s.transactionStatusUnknown,
    };
  }

  String _sourceText(BuildContext context) {
    final s = S.of(context);
    return switch (source) {
      WalletTransactionSource.local => s.transactionSourceLocal,
      WalletTransactionSource.remote => s.transactionSourceRemote,
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 66.w,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
