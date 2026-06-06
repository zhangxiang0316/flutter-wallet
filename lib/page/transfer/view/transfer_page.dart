import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../common/theme/app_theme_extension.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

class TransferPageArguments {
  const TransferPageArguments({
    required this.privateKeyHex,
    required this.asset,
  });

  final String privateKeyHex;
  final ChainBalance asset;
}

class TransferPage extends BaseScaffoldPage<TransferController> {
  @override
  TransferController generateController() {
    return TransferController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(title: Text(S.of(context!).transfer));
  }

  @override
  Widget? getBody() {
    final args = controller.arguments;
    if (args == null) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(16.w),
          padding: EdgeInsets.all(18.w),
          decoration: _panelDecoration(),
          child: Text(
            S.of(context!).transferUnavailable,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(args.asset),
          SizedBox(height: 16.h),
          _buildForm(args.asset),
          SizedBox(height: 16.h),
          _buildFeePanel(args.asset),
          if (controller.transactionHash.isNotEmpty) ...[
            SizedBox(height: 16.h),
            _buildSubmittedPanel(),
          ],
        ],
      ),
    );
  }

  Widget _buildHero(ChainBalance asset) {
    final assetColor = _assetColor(asset.symbol);
    final chainColor = _chainColor(asset.chain);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).colorScheme.primary,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context!,
            ).colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 18.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18.w,
            top: -22.h,
            child: Icon(
              Icons.north_east_rounded,
              size: 128.w,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46.w,
                    height: 46.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      asset.symbol.characters.first,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context!).transferAsset(asset.symbol),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          asset.chain.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      asset.chain.symbol,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ).marginOnly(bottom: 22.h),
              Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 42.h,
                    decoration: BoxDecoration(
                      color: assetColor,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ).marginOnly(right: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context!).availableBalance,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12.sp,
                          ),
                        ),
                        Text(
                          '${asset.amount} ${asset.symbol}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: chainColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 19.w,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ChainBalance asset) {
    final colorScheme = Theme.of(context!).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: _panelDecoration(),
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
                S.of(context!).transferDetails,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
              ),
            ],
          ).marginOnly(bottom: 16.h),
          TextField(
            controller: controller.addressController,
            enabled: !controller.isSubmitting,
            decoration: _inputDecoration(
              label: S.of(context!).recipientAddress,
              hint: asset.chain == WalletChain.bsc ? '0x...' : 'T...',
              icon: Icons.account_circle_outlined,
            ),
          ).marginOnly(bottom: 12.h),
          TextField(
            controller: controller.amountController,
            enabled: !controller.isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              label: S.of(context!).transferAmount,
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
              onPressed: controller.isSubmitting ? null : controller.submit,
              icon: controller.isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.north_east_rounded),
              label: Text(
                S.of(context!).confirmTransfer,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
  }) {
    final colorScheme = Theme.of(context!).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: colorScheme.onSurface.withValues(alpha: 0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(
          color: context!.appTheme.dividerColor!.withValues(alpha: 0.58),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(
          color: context!.appTheme.dividerColor!.withValues(alpha: 0.58),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    );
  }

  Widget _buildFeePanel(ChainBalance asset) {
    final chainColor = _chainColor(asset.chain);
    final estimate = controller.feeEstimate;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: chainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: chainColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chainColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(Icons.bolt_rounded, color: chainColor, size: 21.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context!).estimatedNetworkFee,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (controller.isEstimatingFee)
                  Row(
                    children: [
                      SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ).marginOnly(right: 6.w),
                      Text(
                        S.of(context!).feeEstimating,
                        style: _feeTextStyle(),
                      ),
                    ],
                  )
                else if (estimate != null)
                  Text(
                    estimate.isFallback
                        ? S.of(context!).feeFallback(estimate.displayText)
                        : estimate.displayText,
                    style: TextStyle(
                      fontSize: 15.sp,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context!).colorScheme.onSurface,
                    ),
                  )
                else
                  Text(
                    controller.feeEstimateUnavailable
                        ? S.of(context!).feeUnavailable
                        : S.of(context!).networkFeeAsset(asset.chain.symbol),
                    style: _feeTextStyle(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _feeTextStyle() {
    return TextStyle(
      fontSize: 12.sp,
      height: 1.25,
      color: Theme.of(context!).colorScheme.onSurface.withValues(alpha: 0.64),
    );
  }

  Widget _buildSubmittedPanel() {
    final successColor = context!.appTheme.successColor!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: successColor.withValues(alpha: 0.22)),
      ),
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
                  color: successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: successColor,
                  size: 22.w,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  S.of(context!).transferSubmitted,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ).marginOnly(bottom: 14.h),
          Text(
            S.of(context!).transactionHash,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(
                context!,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Theme.of(context!).cardColor.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: context!.appTheme.dividerColor!.withValues(alpha: 0.45),
              ),
            ),
            child: SelectableText(
              controller.transactionHash,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ).marginOnly(bottom: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.copyTransactionHash,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(S.of(context!).copyHash),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: controller.backToWallet,
                  child: Text(S.of(context!).backToWallet),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Theme.of(context!).cardColor,
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(
        color: context!.appTheme.dividerColor!.withValues(alpha: 0.45),
      ),
      boxShadow: [
        BoxShadow(
          color: context!.appTheme.cardShadowColor ?? Colors.transparent,
          blurRadius: 14.r,
          offset: Offset(0, 6.h),
        ),
      ],
    );
  }

  Color _chainColor(WalletChain chain) {
    switch (chain) {
      case WalletChain.bsc:
        return const Color(0xFFF0B90B);
      case WalletChain.tron:
        return const Color(0xFFE50914);
    }
  }

  Color _assetColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'USDT':
        return const Color(0xFF26A17B);
      case 'USDC':
        return const Color(0xFF2775CA);
      case 'BTCB':
        return const Color(0xFFF7931A);
      case 'ETH':
        return const Color(0xFF627EEA);
      case 'TRX':
        return const Color(0xFFE50914);
      default:
        return Theme.of(context!).colorScheme.primary;
    }
  }
}

class TransferController extends BaseController {
  TransferController({WalletTransferService? transferService})
    : _transferService = transferService ?? WalletTransferService();

  final WalletTransferService _transferService;
  final TextEditingController addressController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  TransferPageArguments? arguments;
  bool isSubmitting = false;
  bool isEstimatingFee = false;
  bool feeEstimateUnavailable = false;
  TransferFeeEstimate? feeEstimate;
  String transactionHash = '';
  Timer? _feeDebounce;
  int _feeRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is TransferPageArguments) {
      arguments = value;
      addressController.addListener(_scheduleFeeEstimate);
      amountController.addListener(_scheduleFeeEstimate);
    }
  }

  Future<void> submit() async {
    final args = arguments;
    if (args == null || isSubmitting) return;

    try {
      WalletTransferService.amountToRawUnits(
        amountController.text.trim(),
        args.asset.decimals,
      );
      _validateAddress(args.asset, addressController.text.trim());
    } catch (_) {
      Toast.show(S.current.transferInputInvalid);
      return;
    }

    try {
      isSubmitting = true;
      transactionHash = '';
      update();
      final hash = await _transferService.transfer(
        privateKeyHex: args.privateKeyHex,
        asset: args.asset,
        toAddress: addressController.text.trim(),
        amount: amountController.text.trim(),
      );
      transactionHash = hash;
      Toast.show(S.current.transferSubmitted);
    } catch (_) {
      Toast.show(S.current.transferFailed);
    } finally {
      isSubmitting = false;
      update();
    }
  }

  void _validateAddress(ChainBalance asset, String address) {
    switch (asset.chain) {
      case WalletChain.bsc:
        WalletTransferService.normalizeBscAddress(address);
        break;
      case WalletChain.tron:
        WalletTransferService.tronAddressToHex(address);
        break;
    }
  }

  void _scheduleFeeEstimate() {
    _feeDebounce?.cancel();
    _feeDebounce = Timer(const Duration(milliseconds: 500), estimateFee);
  }

  Future<void> estimateFee() async {
    final args = arguments;
    if (args == null) return;

    final address = addressController.text.trim();
    final amount = amountController.text.trim();
    if (address.isEmpty || amount.isEmpty) {
      feeEstimate = null;
      feeEstimateUnavailable = false;
      isEstimatingFee = false;
      update();
      return;
    }

    try {
      WalletTransferService.amountToRawUnits(amount, args.asset.decimals);
      _validateAddress(args.asset, address);
    } catch (_) {
      feeEstimate = null;
      feeEstimateUnavailable = false;
      isEstimatingFee = false;
      update();
      return;
    }

    final requestId = ++_feeRequestId;
    isEstimatingFee = true;
    feeEstimateUnavailable = false;
    update();
    try {
      final estimate = await _transferService.estimateFee(
        asset: args.asset,
        toAddress: address,
        amount: amount,
      );
      if (requestId != _feeRequestId) return;
      feeEstimate = estimate;
      feeEstimateUnavailable = false;
    } catch (_) {
      if (requestId != _feeRequestId) return;
      feeEstimate = null;
      feeEstimateUnavailable = true;
    } finally {
      if (requestId == _feeRequestId) {
        isEstimatingFee = false;
        update();
      }
    }
  }

  void copyTransactionHash() {
    if (transactionHash.isEmpty) return;
    Clipboard.setData(ClipboardData(text: transactionHash));
    Toast.show(S.current.copied);
  }

  void backToWallet() {
    Get.back(result: transactionHash.isNotEmpty);
  }

  @override
  void onClose() {
    _feeDebounce?.cancel();
    addressController.dispose();
    amountController.dispose();
    super.onClose();
  }
}
