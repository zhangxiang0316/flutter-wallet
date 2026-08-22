import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'receive_styles.dart';

/// 二维码和地址展示面板。
///
/// 二维码内容直接使用当前链地址。币种本身不改变地址，但会通过页面上下文
/// 提醒用户只向当前网络转入所选资产。
class ReceiveQrAddressPanel extends StatelessWidget {
  const ReceiveQrAddressPanel({
    super.key,
    required this.chain,
    required this.address,
    required this.qrData,
    required this.onCopyPressed,
  });

  /// 当前二维码对应的链。
  final WalletChainConfig chain;

  /// 当前链的钱包地址。
  final String address;

  /// 当前二维码内容，可能是纯地址，也可能是带金额/备注的收款 URI。
  final String qrData;

  /// 复制地址按钮回调。
  final VoidCallback onCopyPressed;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    final hasQrData = qrData.trim().isNotEmpty;
    final color = receiveChainColor(chain);
    return ReceivePanel(
      title: S.of(context).receiveQrTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 226.w,
              height: 226.w,
              padding: EdgeInsets.all(13.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.w),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: hasQrData
                  ? QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: color,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: Color(0xFF111827),
                      ),
                    )
                  : Icon(
                      Icons.qr_code_2_rounded,
                      size: 94.w,
                      color: const Color(0xFF9CA3AF),
                    ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            S.of(context).receiveQrNetworkTip(chain.name),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.56),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 13.h),
          _AddressBox(
            label: S.of(context).receiveAddress,
            address: hasAddress ? address : S.of(context).receiveAddressEmpty,
            enabled: hasAddress,
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 44.h,
            child: FilledButton.icon(
              onPressed: hasAddress ? onCopyPressed : null,
              icon: Icon(Icons.copy_rounded, size: 17.w),
              label: Text(
                S.of(context).copyReceiveAddress,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 地址文本展示框。
///
/// 使用 [SelectableText] 允许用户长按选择，同时按钮提供一键复制。
class _AddressBox extends StatelessWidget {
  const _AddressBox({
    required this.label,
    required this.address,
    required this.enabled,
  });

  /// 地址区标题。
  final String label;

  /// 展示的地址或空地址提示。
  final String address;

  /// 当前地址是否可用。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: receiveDividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.54),
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 7.h),
          SelectableText(
            address,
            style: TextStyle(
              color: enabled
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.42),
              fontSize: 12.sp,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
