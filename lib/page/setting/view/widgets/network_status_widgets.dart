import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/services/wallet_rpc_health_service.dart';

/// RPC 连接状态标签。
///
/// 根据检测结果显示不同颜色和文案：可用（绿色）、不可用（红色）、
/// 备用可用（蓝色）、检测中（主色）、未检测（灰色）。
class RpcStatusPill extends StatelessWidget {
  const RpcStatusPill({
    super.key,
    required this.result,
    required this.isTesting,
  });

  /// RPC 健康检测结果，为 null 表示尚未检测。
  final WalletRpcHealthResult? result;

  /// 是否正在检测中。
  final bool isTesting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color, icon) = _statusMeta(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.w, color: color),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              color: result == null && !isTesting
                  ? colorScheme.onSurface.withValues(alpha: 0.58)
                  : color,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _statusMeta(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isTesting) {
      return (
        S.of(context).networkRpcTesting,
        colorScheme.primary,
        Icons.sync_rounded,
      );
    }
    final current = result;
    if (current == null) {
      return (
        S.of(context).networkRpcNotTested,
        colorScheme.onSurface.withValues(alpha: 0.58),
        Icons.help_outline_rounded,
      );
    }
    if (current.isAvailable) {
      return (
        S.of(context).networkRpcLatency('${current.latencyMs ?? '-'}'),
        const Color(0xFF10B981),
        Icons.check_circle_rounded,
      );
    }
    return (
      S.of(context).networkRpcDown,
      colorScheme.error,
      Icons.error_rounded,
    );
  }
}

/// 备用 RPC 节点切换提示。
///
/// 当检测到更优的备用节点时展示，包含延迟信息和一键切换按钮。
class BackupRpcHint extends StatelessWidget {
  const BackupRpcHint({
    super.key,
    required this.result,
    required this.onSwitchPressed,
  });

  /// 备用节点的检测结果。
  final WalletRpcHealthResult result;

  /// 点击切换按钮的回调。
  final VoidCallback onSwitchPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(9.w),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 15.w,
                color: const Color(0xFF10B981),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  S
                      .of(context)
                      .networkRpcBackupHint(
                        result.latencyMs?.toString() ?? '-',
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF047857),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSwitchPressed,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  minimumSize: Size(0, 28.h),
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  textStyle: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: Text(S.of(context).networkRpcSwitch),
              ),
            ],
          ),
          Text(
            result.rpcUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
