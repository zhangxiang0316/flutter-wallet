import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
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
      return Center(child: Text(S.of(context!).transferUnavailable));
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
    final colorScheme = Theme.of(context!).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  asset.symbol.characters.first,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      asset.chain.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).marginOnly(bottom: 18.h),
          Text(
            S.of(context!).availableBalance,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.sp,
            ),
          ),
          Text(
            '${asset.amount} ${asset.symbol}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ChainBalance asset) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).cardColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context!).transferDetails,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
          ).marginOnly(bottom: 14.h),
          TextField(
            controller: controller.addressController,
            enabled: !controller.isSubmitting,
            decoration: InputDecoration(
              labelText: S.of(context!).recipientAddress,
              hintText: asset.chain == WalletChain.bsc ? '0x...' : 'T...',
              prefixIcon: const Icon(Icons.account_circle_outlined),
              border: const OutlineInputBorder(),
            ),
          ).marginOnly(bottom: 12.h),
          TextField(
            controller: controller.amountController,
            enabled: !controller.isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: S.of(context!).transferAmount,
              suffixText: asset.symbol,
              prefixIcon: const Icon(Icons.payments_outlined),
              border: const OutlineInputBorder(),
            ),
          ).marginOnly(bottom: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.isSubmitting ? null : controller.submit,
              icon: controller.isSubmitting
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(S.of(context!).confirmTransfer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeePanel(ChainBalance asset) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: Theme.of(context!).dividerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bolt_outlined,
            color: Theme.of(context!).colorScheme.primary,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context!).networkFee,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  S.of(context!).networkFeeAsset(asset.chain.symbol),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(
                      context!,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedPanel() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context!).colorScheme.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                S.of(context!).transferSubmitted,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
              ),
            ],
          ).marginOnly(bottom: 12.h),
          Text(
            S.of(context!).transactionHash,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(
                context!,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          SelectableText(
            controller.transactionHash,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          ).marginOnly(bottom: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.copyTransactionHash,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(S.of(context!).copyHash),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
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
}

class TransferController extends BaseController {
  TransferController({WalletTransferService? transferService})
    : _transferService = transferService ?? WalletTransferService();

  final WalletTransferService _transferService;
  final TextEditingController addressController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  TransferPageArguments? arguments;
  bool isSubmitting = false;
  String transactionHash = '';

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is TransferPageArguments) {
      arguments = value;
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
    addressController.dispose();
    amountController.dispose();
    super.onClose();
  }
}
