import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/wallet_secret_store.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

class TransferPageArguments {
  const TransferPageArguments({required this.walletId, required this.asset});

  final String walletId;
  final ChainBalance asset;
}

class TransferController extends BaseController {
  TransferController({
    WalletTransferService? transferService,
    WalletRepository? repository,
  }) : _transferService = transferService ?? WalletTransferService(),
       _repository = repository ?? WalletRepository();

  final WalletTransferService _transferService;
  final WalletRepository _repository;
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

  bool validateTransferInput() {
    final args = arguments;
    if (args == null) return false;

    try {
      WalletTransferService.amountToRawUnits(
        amountController.text.trim(),
        args.asset.decimals,
      );
      _validateAddress(args.asset, addressController.text.trim());
    } catch (_) {
      Toast.show(S.current.transferInputInvalid);
      return false;
    }
    return true;
  }

  Future<void> submit(String password) async {
    final args = arguments;
    if (args == null || isSubmitting) return;
    if (!validateTransferInput()) return;
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }

    try {
      isSubmitting = true;
      transactionHash = '';
      update();
      final privateKeyHex = await _repository.readWalletPrivateKey(
        walletId: args.walletId,
        password: password,
      );
      final solanaPrivateKey = args.asset.chain == WalletChain.solana
          ? await _repository.readWalletSolanaPrivateKey(
              walletId: args.walletId,
              password: password,
            )
          : null;
      final hash = await _transferService.transfer(
        privateKeyHex: privateKeyHex,
        asset: args.asset,
        toAddress: addressController.text.trim(),
        amount: amountController.text.trim(),
        solanaPrivateKey: solanaPrivateKey,
      );
      transactionHash = hash;
      Toast.show(S.current.transferSubmitted);
    } on WalletSecretMissingException {
      Toast.show(S.current.walletSecretMissing);
    } on WalletSecretInvalidPasswordException {
      Toast.show(S.current.invalidWalletPassword);
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
      case WalletChain.ethereum:
      case WalletChain.xLayer:
        WalletTransferService.normalizeEvmAddress(address);
        break;
      case WalletChain.tron:
        WalletTransferService.tronAddressToHex(address);
        break;
      case WalletChain.solana:
        WalletTransferService.normalizeSolanaAddress(address);
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
