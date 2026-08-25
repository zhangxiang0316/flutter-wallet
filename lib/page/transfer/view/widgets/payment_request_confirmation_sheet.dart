import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../controller/transfer_controller.dart';
import 'transfer_styles.dart';

/// 扫码付款请求二次确认面板。
class PaymentRequestConfirmationSheet extends StatelessWidget {
  const PaymentRequestConfirmationSheet({super.key, required this.resolution});

  final PaymentRequestResolution resolution;

  static Future<bool> show(
    BuildContext context,
    PaymentRequestResolution resolution,
  ) async {
    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              PaymentRequestConfirmationSheet(resolution: resolution),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final request = resolution.request;
    final targetAsset = resolution.targetAsset;
    final networkName = targetAsset.chainRef.name;
    return Container(
      constraints: BoxConstraints(maxHeight: 0.86.sh),
      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 18.h),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: transferChainColor(
                        context,
                        targetAsset.chainRef,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 23.w,
                      color: transferChainColor(context, targetAsset.chainRef),
                    ),
                  ),
                ),
                SizedBox(width: 11.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).paymentRequestConfirmTitle,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        S.of(context).paymentRequestConfirmTip,
                        style: TextStyle(
                          fontSize: 11.sp,
                          height: 1.3,
                          color: colorScheme.onSurface.withValues(alpha: 0.56),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            if (request.isPlainAddress)
              _Warning(
                text: S
                    .of(context)
                    .paymentRequestPlainAddressNetwork(networkName),
              ),
            if (resolution.requiresNetworkSwitch)
              _Warning(
                text: S
                    .of(context)
                    .paymentRequestNetworkSwitch(
                      resolution.currentAsset.chainRef.name,
                      networkName,
                    ),
              ),
            if (resolution.requiresAssetSwitch)
              _Warning(
                text: S
                    .of(context)
                    .paymentRequestAssetSwitch(
                      resolution.currentAsset.symbol,
                      targetAsset.symbol,
                    ),
              ),
            if (resolution.overwritesAmount)
              _Warning(text: S.of(context).paymentRequestAmountOverwrite),
            _DetailRow(label: S.of(context).network, value: networkName),
            _DetailRow(
              label: S.of(context).selectTransferAsset,
              value: targetAsset.symbol,
            ),
            _DetailRow(
              label: S.of(context).recipientAddress,
              value: request.address,
              selectable: true,
            ),
            if (request.contractAddress != null)
              _DetailRow(
                label: S.of(context).tokenContractAsset,
                value: request.contractAddress!,
                selectable: true,
              ),
            if (request.amount != null)
              _DetailRow(
                label: S.of(context).transferAmount,
                value: '${request.amount} ${targetAsset.symbol}',
              ),
            if (request.memo != null) ...[
              _DetailRow(
                label: S.of(context).receiveMemo,
                value: request.memo!,
              ),
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Text(
                  S.of(context).paymentRequestMemoReferenceOnly,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    height: 1.3,
                    color: colorScheme.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ),
            ],
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(S.of(context).cancel),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(S.of(context).paymentRequestApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16.w,
            color: colorScheme.onTertiaryContainer,
          ),
          SizedBox(width: 7.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 12.sp,
      height: 1.35,
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.56),
              ),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: valueStyle)
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
