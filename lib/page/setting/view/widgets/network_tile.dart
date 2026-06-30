import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_chain.dart';
import '../../../../wallet/services/wallet_rpc_health_service.dart';
import 'network_status_widgets.dart';
import 'network_styles.dart';

/// 网络管理列表中的单条网络条目。
///
/// 展示链名称、符号、Chain ID、RPC 状态和健康检测结果。
/// 内置链不可删除，自定义链支持启用/禁用开关。
class NetworkTile extends StatelessWidget {
  const NetworkTile({
    super.key,
    required this.chain,
    required this.healthReport,
    required this.isTesting,
    required this.onEnabledChanged,
    required this.onEditPressed,
    required this.onRemovePressed,
    required this.onTestPressed,
    required this.onSwitchRpcPressed,
  });

  /// 链配置数据。
  final WalletChainConfig chain;

  /// RPC 健康检测报告。
  final WalletChainRpcHealthReport? healthReport;

  /// 是否正在检测中。
  final bool isTesting;

  /// 启用/禁用切换回调，内置链传入 null 表示不可切换。
  final ValueChanged<bool>? onEnabledChanged;

  /// 点击编辑按钮的回调。
  final VoidCallback? onEditPressed;

  /// 点击删除按钮的回调，内置链传入 null 表示不可删除。
  final VoidCallback? onRemovePressed;

  /// 点击"测试"按钮的回调。
  final VoidCallback onTestPressed;

  /// 切换备用 RPC 节点的回调。
  final ValueChanged<String> onSwitchRpcPressed;

  @override
  Widget build(BuildContext context) {
    final color = Color(chain.colorValue ?? 0xFF2563EB);
    final colorScheme = Theme.of(context).colorScheme;
    final primaryResult = healthReport?.primaryResult;
    final bestResult = healthReport?.bestAvailableResult;
    final canSwitch =
        bestResult != null && bestResult.rpcUrl.trim() != chain.rpcUrl.trim();
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: panelDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  chain.symbol.characters.first,
                  style: TextStyle(
                    color: color,
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
                      chain.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      chain.isEvm
                          ? '${chain.symbol} · Chain ID ${chain.evmChainId}'
                          : chain.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.52),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: chain.isEnabled, onChanged: onEnabledChanged),
              if (onEditPressed != null)
                IconButton(
                  tooltip: S.of(context).editNetwork,
                  onPressed: onEditPressed,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 19.w,
                    color: colorScheme.primary,
                  ),
                ),
              if (onRemovePressed != null)
                IconButton(
                  tooltip: S.of(context).removeNetwork,
                  onPressed: onRemovePressed,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20.w,
                    color: colorScheme.error,
                  ),
                ),
            ],
          ),
          Divider(
            height: 18.h,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RpcStatusPill(result: primaryResult, isTesting: isTesting),
                    SizedBox(height: 7.h),
                    Text(
                      chain.rpcUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.52),
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canSwitch) ...[
                      SizedBox(height: 7.h),
                      BackupRpcHint(
                        result: bestResult,
                        onSwitchPressed: () =>
                            onSwitchRpcPressed(bestResult.rpcUrl),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              OutlinedButton.icon(
                onPressed: isTesting ? null : onTestPressed,
                icon: isTesting
                    ? SizedBox(
                        width: 13.w,
                        height: 13.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Icon(Icons.speed_rounded, size: 15.w),
                label: Text(S.of(context).networkRpcTest),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  minimumSize: Size(0, 32.h),
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  textStyle: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.22),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
