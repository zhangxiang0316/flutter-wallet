import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/models/wallet_chain.dart';
import '../../controller/transfer_controller.dart';
import 'transfer_styles.dart';

/// 转账表单面板。
///
/// 包含收款地址、转账金额和确认按钮。点击确认后先进行本地输入校验，
/// 再弹出钱包密码输入框，由控制器完成私钥解锁和链上提交。
class TransferFormPanel extends StatelessWidget {
  const TransferFormPanel({
    super.key,
    required this.asset,
    required this.controller,
  });

  /// 当前要转出的资产。
  final ChainBalance asset;

  /// 页面控制器，持有输入框和提交状态。
  final TransferController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: transferPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  size: 22.w,
                  color: colorScheme.primary,
                ),
              ).marginOnly(right: 10.w),
              Text(
                S.of(context).transferDetails,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ).marginOnly(bottom: 16.h),
          TextField(
            controller: controller.addressController,
            enabled: !controller.isSubmitting,
            style: transferInputTextStyle(context),
            decoration: transferInputDecoration(
              context,
              label: S.of(context).recipientAddress,
              hint: _addressHint(asset),
              icon: Icons.account_circle_outlined,
            ),
          ).marginOnly(bottom: 12.h),
          TextField(
            controller: controller.amountController,
            enabled: !controller.isSubmitting,
            style: transferInputTextStyle(context),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: transferInputDecoration(
              context,
              label: S.of(context).transferAmount,
              icon: Icons.payments_outlined,
              suffix: asset.symbol,
            ),
          ).marginOnly(bottom: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: controller.isSubmitting
                  ? null
                  : () => _showUnlockSheet(context),
              icon: controller.isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.outbound_rounded),
              label: Text(
                S.of(context).confirmTransfer,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开钱包密码解锁弹窗。
  ///
  /// 这里不直接读取私钥，只把用户输入的密码交给控制器继续处理。
  Future<void> _showUnlockSheet(BuildContext context) async {
    if (!controller.validateTransferInput()) return;

    final passwordController = TextEditingController();
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 4.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      size: 19.w,
                      color: colorScheme.primary,
                    ),
                  ).marginOnly(right: 10.w),
                  Expanded(
                    child: Text(
                      S.of(sheetContext).unlockWallet,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ).marginOnly(bottom: 12.h),
              Text(
                S.of(sheetContext).unlockWalletForTransfer,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  height: 1.35,
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ).marginOnly(bottom: 14.h),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                style: transferInputTextStyle(sheetContext),
                decoration: transferInputDecoration(
                  sheetContext,
                  label: S.of(sheetContext).walletPassword,
                  icon: Icons.lock_outline_rounded,
                ),
                onSubmitted: (_) => _submitPassword(
                  sheetContext,
                  passwordController.text.trim(),
                ),
              ).marginOnly(bottom: 14.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(42.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () => _submitPassword(
                    sheetContext,
                    passwordController.text.trim(),
                  ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    S.of(sheetContext).confirmTransfer,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    passwordController.dispose();
    if (password == null) return;
    await controller.submit(password);
  }

  /// 提交密码输入框内容并关闭底部弹窗。
  void _submitPassword(BuildContext context, String password) {
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }
    Navigator.of(context).pop(password);
  }

  /// 根据链类型返回地址输入框占位提示。
  String _addressHint(ChainBalance asset) {
    switch (asset.chain) {
      case WalletChain.bsc:
      case WalletChain.ethereum:
      case WalletChain.xLayer:
        return '0x...';
      case WalletChain.tron:
        return 'T...';
      case WalletChain.solana:
        return 'Solana address';
    }
  }
}
