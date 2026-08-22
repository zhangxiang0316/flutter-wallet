import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../controller/receive_controller.dart';
import 'receive_styles.dart';

/// 收款请求信息面板。
///
/// 用户可以输入金额和备注，二维码会跟随这些字段生成带参数的收款 payload。
class ReceiveRequestPanel extends StatelessWidget {
  const ReceiveRequestPanel({super.key, required this.controller});

  /// 收款页面控制器。
  final ReceiveController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ReceivePanel(
      title: S.of(context).receiveRequestTitle,
      child: Column(
        children: [
          TextField(
            controller: controller.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,18}')),
            ],
            decoration:
                _inputDecoration(
                  context,
                  label: S.of(context).receiveAmount,
                  hint: S.of(context).receiveAmountHint,
                  icon: Icons.payments_rounded,
                ).copyWith(
                  errorText: controller.isRequestAmountValid
                      ? null
                      : S.of(context).receiveAmountInvalid,
                ),
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: controller.memoController,
            maxLength: 80,
            decoration: _inputDecoration(
              context,
              label: S.of(context).receiveMemo,
              hint: S.of(context).receiveMemoHint,
              icon: Icons.notes_rounded,
            ).copyWith(counterText: ''),
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 9.h),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14.w,
                color: colorScheme.onSurface.withValues(alpha: 0.46),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  S.of(context).receiveRequestTip,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.52),
                    fontSize: 10.5.sp,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18.w),
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.72),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: receiveDividerColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: receiveDividerColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
      ),
      labelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.58),
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.34),
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
