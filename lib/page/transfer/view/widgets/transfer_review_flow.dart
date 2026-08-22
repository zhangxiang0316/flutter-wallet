import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import '../../../../utils/toast_util.dart';
import '../../../../utils/transaction_risk_checker.dart';
import '../../../../wallet/models/chain_balance.dart';
import '../../../../wallet/models/wallet_chain.dart';
import '../../../../wallet/models/wallet_chain_extensions.dart';
import '../../../../wallet/services/wallet_transfer_service.dart';
import '../../../../widget/transaction_review_sheet.dart';
import '../../controller/transfer_controller.dart';
import 'transfer_styles.dart';

class TransferReviewFlow {
  const TransferReviewFlow._();

  /// 显示交易审查弹窗；用户批准后再显示钱包密码弹窗，最后提交交易。
  static Future<void> show(
    BuildContext context,
    TransferController controller,
  ) async {
    if (!controller.validateTransferInput()) return;

    final asset = controller.currentAsset;
    if (asset == null) return;

    final approved = await _showReviewSheet(context, controller, asset);
    if (!context.mounted) return;
    if (approved != true) return;

    final password = await _showPasswordSheet(context, controller, asset);
    if (password == null) return;

    await controller.submit(password);
  }

  static Future<bool?> _showReviewSheet(
    BuildContext context,
    TransferController controller,
    ChainBalance asset,
  ) async {
    final amount = controller.amountController.text.trim();
    final recipientAddress = controller.addressController.text.trim();
    final feeEstimate = controller.feeEstimate;
    final clipboardText = await _readClipboardText();
    if (!context.mounted) return null;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TransactionReviewSheet(
          title: S.of(context).reviewTransfer,
          items: _buildReviewItems(
            context,
            controller,
            asset,
            amount,
            recipientAddress,
            feeEstimate,
          ),
          risks: _detectRisks(
            context,
            asset,
            amount,
            recipientAddress,
            feeEstimate,
            clipboardText,
          ),
          onApprove: () => Navigator.of(context).pop(true),
          onReject: () => Navigator.of(context).pop(false),
        );
      },
    );
  }

  static Future<String?> _showPasswordSheet(
    BuildContext context,
    TransferController controller,
    ChainBalance asset,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        return _TransferPasswordSheet(
          summary: _buildTransactionSummary(sheetContext, controller, asset),
        );
      },
    );
  }

  static Widget _buildTransactionSummary(
    BuildContext context,
    TransferController controller,
    ChainBalance asset,
  ) {
    final theme = Theme.of(context);
    final recipientAddress = controller.addressController.text.trim();
    final amount = controller.amountController.text.trim();
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

  static List<TransactionRisk> _detectRisks(
    BuildContext context,
    ChainBalance asset,
    String amount,
    String recipientAddress,
    TransferFeeEstimate? feeEstimate,
    String? clipboardText,
  ) {
    final s = S.of(context);
    final risks = TransactionRiskChecker.checkAllRisks(
      amount: amount,
      balance: asset.amount,
      recipientAddress: recipientAddress,
      historyAddresses: const [],
      fee: feeEstimate?.amount,
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
            caseInsensitive:
                asset.chainRef.isEvm ||
                asset.chainRef.isBitcoin ||
                asset.chainRef.isSui ||
                asset.chainRef.isAptos,
          )
          case final risk?)
        risk,
      if (TransactionRiskChecker.checkTokenContractRecipient(
            recipientAddress: recipientAddress,
            contractAddress: asset.contractAddress,
            message: s.transferRiskTokenContract,
            caseInsensitive:
                asset.chainRef.isEvm ||
                asset.chainRef.isSui ||
                asset.chainRef.isAptos,
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
            isSui: asset.chainRef.isSui,
            isAptos: asset.chainRef.isAptos,
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
      caseInsensitive:
          asset.chainRef.isEvm ||
          asset.chainRef.isBitcoin ||
          asset.chainRef.isSui ||
          asset.chainRef.isAptos,
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

  static List<ReviewItem> _buildReviewItems(
    BuildContext context,
    TransferController controller,
    ChainBalance asset,
    String amount,
    String recipientAddress,
    TransferFeeEstimate? feeEstimate,
  ) {
    final args = controller.arguments;
    final walletName = args != null ? 'Wallet' : 'Current Wallet';
    final chainName = asset.chainConfig?.name ?? asset.chainRef.name;
    final items = <ReviewItem>[
      ReviewItem(
        label: S.current.transactionFrom,
        value: walletName,
        icon: Icon(Icons.account_balance_wallet, size: 18.sp),
      ),
      ReviewItem(
        label: S.current.transactionTo,
        value: recipientAddress,
        copyable: true,
      ),
      ReviewItem(
        label: S.current.transactionAmount,
        value: '$amount ${asset.symbol}',
        highlight: true,
        icon: Icon(
          Icons.payments,
          size: 18.sp,
          color: Theme.of(context).primaryColor,
        ),
      ),
      ReviewItem(
        label: S.current.network,
        value: chainName,
        icon: Icon(Icons.language, size: 18.sp),
      ),
    ];

    if (feeEstimate != null && feeEstimate.amount.isNotEmpty) {
      items.add(
        ReviewItem(
          label: S.current.estimatedNetworkFeeOnNetwork(chainName),
          value: '${feeEstimate.amount} ${feeEstimate.symbol}',
        ),
      );
      if (feeEstimate.symbol == asset.symbol) {
        final amountValue = double.tryParse(amount);
        final feeValue = double.tryParse(feeEstimate.amount);
        if (amountValue != null && feeValue != null) {
          items.add(
            ReviewItem(
              label: S.current.totalTransferCost,
              value:
                  '${(amountValue + feeValue).toStringAsFixed(6)} ${asset.symbol}',
              highlight: true,
            ),
          );
        }
      }
    } else {
      items.add(
        ReviewItem(
          label: S.current.estimatedNetworkFeeOnNetwork(chainName),
          value: S.current.feeEstimating,
        ),
      );
    }

    return items;
  }

  static Future<String?> _readClipboardText() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      return null;
    }
  }

  static String? _extractAddressFromTextForAsset(
    ChainBalance asset,
    String value,
  ) {
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
    if (asset.chainRef.id == WalletChain.bitcoin.id ||
        asset.chainConfig?.type == WalletChainType.bitcoin) {
      return RegExp(
        r'(?<![02-9ac-hj-np-z])bc1q[02-9ac-hj-np-z]{38}(?![02-9ac-hj-np-z])',
        caseSensitive: false,
      ).firstMatch(value)?.group(0);
    }
    if (asset.chainRef.isSui) {
      return RegExp(r'0x[a-fA-F0-9]{64}').firstMatch(value)?.group(0);
    }
    if (asset.chainRef.isAptos) {
      return RegExp(
        r'(?<![a-fA-F0-9])0x[a-fA-F0-9]{1,64}(?![a-fA-F0-9])',
      ).firstMatch(value)?.group(0);
    }
    return null;
  }
}

class _TransferPasswordSheet extends StatefulWidget {
  const _TransferPasswordSheet({required this.summary});

  final Widget summary;

  @override
  State<_TransferPasswordSheet> createState() => _TransferPasswordSheetState();
}

class _TransferPasswordSheetState extends State<_TransferPasswordSheet> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 4.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18.h,
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
                  S.of(context).unlockWallet,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ).marginOnly(bottom: 12.h),
          widget.summary,
          SizedBox(height: 14.h),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            style: transferInputTextStyle(context),
            decoration: transferInputDecoration(
              context,
              label: S.of(context).walletPassword,
              icon: Icons.lock_outline_rounded,
            ),
            onSubmitted: (_) => _submitPassword(),
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
              onPressed: _submitPassword,
              icon: const Icon(Icons.verified_user_outlined),
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

  void _submitPassword() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }
    Navigator.of(context).pop(password);
  }
}
