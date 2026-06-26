import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../utils/transaction_risk_checker.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/models/wallet_chain.dart';
import '../../../../wallet/services/wallet_transfer_service.dart';
import '../../../../widget/transaction_review_sheet.dart';
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
                S.of(context).reviewTransfer,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示交易审查弹窗（新增）
  ///
  /// Step 1: 显示完整交易详情，包括风险警告
  /// 用户点击"Approve"后进入 Step 2（密码认证）
  Future<void> _showUnlockSheet(BuildContext context) async {
    if (!controller.validateTransferInput()) return;

    final asset = controller.currentAsset;
    if (asset == null) return;

    // Step 1: 显示交易审查弹窗
    final approved = await _showReviewSheet(context, asset);
    if (!context.mounted) return;
    if (approved != true) return;

    // Step 2: 用户批准后，显示密码认证弹窗
    final password = await _showPasswordSheet(context, asset);
    if (password == null) return;

    // Step 3: 提交交易
    await controller.submit(password);
  }

  /// Step 1: 显示交易审查弹窗
  Future<bool?> _showReviewSheet(
    BuildContext context,
    ChainBalance asset,
  ) async {
    final amount = controller.amountController.text.trim();
    final recipientAddress = controller.addressController.text.trim();
    final feeEstimate = controller.feeEstimate;
    final clipboardText = await _readClipboardText();
    if (!context.mounted) return null;

    // 检测风险
    final risks = _detectRisks(
      context,
      asset,
      amount,
      recipientAddress,
      feeEstimate,
      clipboardText,
    );

    // 构建详情列表
    final items = _buildReviewItems(
      asset,
      amount,
      recipientAddress,
      feeEstimate,
    );

    // 显示审查弹窗
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TransactionReviewSheet(
          title: S.of(context).reviewTransfer,
          items: items,
          risks: risks,
          onApprove: () => Navigator.of(context).pop(true),
          onReject: () => Navigator.of(context).pop(false),
        );
      },
    );
  }

  /// Step 2: 显示密码认证弹窗
  Future<String?> _showPasswordSheet(
    BuildContext context,
    ChainBalance asset,
  ) async {
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
              // 显示交易摘要
              _buildTransactionSummary(sheetContext, asset),
              SizedBox(height: 14.h),
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
    return password;
  }

  /// 提交密码输入框内容并关闭底部弹窗。
  void _submitPassword(BuildContext context, String password) {
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }
    Navigator.of(context).pop(password);
  }

  /// 构建交易摘要显示（在密码弹窗中）
  Widget _buildTransactionSummary(BuildContext context, ChainBalance asset) {
    final theme = Theme.of(context);
    final recipientAddress = controller.addressController.text.trim();
    final amount = controller.amountController.text.trim();

    // 地址缩略显示（前6后4）
    final shortAddress = recipientAddress.length > 10
        ? '${recipientAddress.substring(0, 6)}...${recipientAddress.substring(recipientAddress.length - 4)}'
        : recipientAddress;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).transactionSummary,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: theme.primaryColor,
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(
                '${S.of(context).transactionTo}: ',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
              Text(
                shortAddress,
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                '${S.of(context).transactionAmount}: ',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
              Text(
                '$amount ${asset.symbol}',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 检测交易风险
  List<TransactionRisk> _detectRisks(
    BuildContext context,
    ChainBalance asset,
    String amount,
    String recipientAddress,
    TransferFeeEstimate? feeEstimate,
    String? clipboardText,
  ) {
    final s = S.of(context);
    // 获取历史地址（这里简化处理，实际应该从交易历史中获取）
    final historyAddresses = <String>[];

    final risks = TransactionRiskChecker.checkAllRisks(
      amount: amount,
      balance: asset.amount, // 使用 amount 字段
      recipientAddress: recipientAddress,
      historyAddresses: historyAddresses,
      fee: feeEstimate?.amount, // 使用 amount 字段
    );
    risks.addAll([
      if (feeEstimate == null || feeEstimate.amount.isEmpty)
        TransactionRisk(
          level: RiskLevel.medium,
          message: s.transferRiskFeeUnavailable,
          icon: Icons.info_outline_rounded,
          color: Colors.orange,
        ),
      if (asset.chainRef.isEvm)
        TransactionRisk(
          level: RiskLevel.medium,
          message: s.transferRiskEvmNetworkConfirm(
            asset.chainConfig?.name ?? asset.chainRef.name,
          ),
          icon: Icons.hub_outlined,
          color: Colors.orange,
        ),
      if (TransactionRiskChecker.checkSelfTransfer(
            recipientAddress: recipientAddress,
            walletAddress: asset.address,
            message: s.transferRiskSelfTransfer,
            caseInsensitive: asset.chainRef.isEvm,
          )
          case final risk?)
        risk,
      if (TransactionRiskChecker.checkTokenContractRecipient(
            recipientAddress: recipientAddress,
            contractAddress: asset.contractAddress,
            message: s.transferRiskTokenContract,
            caseInsensitive: asset.chainRef.isEvm,
          )
          case final risk?)
        risk,
      if (TransactionRiskChecker.checkBurnAddress(
            recipientAddress: recipientAddress,
            message: s.transferRiskBurnAddress,
            isEvm: asset.chainRef.isEvm,
            isSolana:
                asset.chainRef.id == WalletChain.solana.id ||
                asset.chainConfig?.type == WalletChainType.solana,
          )
          case final risk?)
        risk,
    ]);

    final clipboardAddress = _extractAddressFromTextForAsset(
      asset,
      clipboardText ?? '',
    );
    final clipboardRisk = TransactionRiskChecker.checkClipboardMismatch(
      recipientAddress: recipientAddress,
      clipboardAddress: clipboardAddress,
      message: s.transferRiskClipboardMismatch,
      caseInsensitive: asset.chainRef.isEvm,
    );
    if (clipboardRisk != null) {
      risks.add(clipboardRisk);
    }

    risks.sort((a, b) {
      const levelOrder = {
        RiskLevel.high: 0,
        RiskLevel.medium: 1,
        RiskLevel.low: 2,
      };
      return (levelOrder[a.level] ?? 2).compareTo(levelOrder[b.level] ?? 2);
    });
    return risks;
  }

  /// 构建审查详情列表
  List<ReviewItem> _buildReviewItems(
    ChainBalance asset,
    String amount,
    String recipientAddress,
    TransferFeeEstimate? feeEstimate,
  ) {
    final args = controller.arguments;
    final walletName = args != null ? 'Wallet' : 'Current Wallet';
    final chainName = asset.chainConfig?.name ?? asset.chainRef.name;
    final items = <ReviewItem>[];

    // From
    items.add(
      ReviewItem(
        label: S.current.transactionFrom,
        value: walletName,
        icon: Icon(Icons.account_balance_wallet, size: 18.sp),
      ),
    );

    // To
    items.add(
      ReviewItem(
        label: S.current.transactionTo,
        value: recipientAddress,
        copyable: true,
      ),
    );

    // Amount
    items.add(
      ReviewItem(
        label: S.current.transactionAmount,
        value: '$amount ${asset.symbol}',
        highlight: true,
        icon: Icon(
          Icons.payments,
          size: 18.sp,
          color: Theme.of(Get.context!).primaryColor,
        ),
      ),
    );

    // Network
    items.add(
      ReviewItem(
        label: S.current.network,
        value: chainName,
        icon: Icon(Icons.language, size: 18.sp),
      ),
    );

    // Fee
    if (feeEstimate != null && feeEstimate.amount.isNotEmpty) {
      items.add(
        ReviewItem(
          label: S.current.estimatedNetworkFee,
          value: '${feeEstimate.amount} ${feeEstimate.symbol}',
        ),
      );

      // Total (Amount + Fee if same currency)
      if (feeEstimate.symbol == asset.symbol) {
        try {
          final amountValue = double.parse(amount);
          final feeValue = double.parse(feeEstimate.amount);
          final total = amountValue + feeValue;
          items.add(
            ReviewItem(
              label: S.current.totalTransferCost,
              value: '${total.toStringAsFixed(6)} ${asset.symbol}',
              highlight: true,
            ),
          );
        } catch (_) {}
      }
    } else {
      items.add(
        ReviewItem(
          label: S.current.estimatedNetworkFee,
          value: S.current.feeEstimating,
        ),
      );
    }

    return items;
  }

  /// 根据链类型返回地址输入框占位提示。
  String _addressHint(ChainBalance asset) {
    if (asset.chainRef.isEvm) {
      return '0x...';
    }
    final chain = asset.chainRef;
    if (chain.id == WalletChain.tron.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.tron)) {
      return 'T...';
    }
    if (chain.id == WalletChain.solana.id ||
        (chain is WalletChainConfig && chain.type == WalletChainType.solana)) {
      return 'Solana address';
    }
    return '0x...';
  }

  Future<String?> _readClipboardText() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      return null;
    }
  }

  String? _extractAddressFromTextForAsset(ChainBalance asset, String value) {
    if (value.trim().isEmpty) return null;
    if (asset.chainRef.isEvm) {
      return RegExp(r'0x[a-fA-F0-9]{40}').firstMatch(value)?.group(0);
    }
    if (asset.chainRef.id == WalletChain.tron.id ||
        asset.chainConfig?.type == WalletChainType.tron) {
      return RegExp(r'T[1-9A-HJ-NP-Za-km-z]{33}').firstMatch(value)?.group(0);
    }
    if (asset.chainRef.id == WalletChain.solana.id ||
        asset.chainConfig?.type == WalletChainType.solana) {
      return RegExp(
        r'(?<![1-9A-HJ-NP-Za-km-z])[1-9A-HJ-NP-Za-km-z]{32,44}(?![1-9A-HJ-NP-Za-km-z])',
      ).firstMatch(value)?.group(0);
    }
    return null;
  }
}
