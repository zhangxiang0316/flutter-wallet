import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
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
      case WalletChain.xLayer:
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
