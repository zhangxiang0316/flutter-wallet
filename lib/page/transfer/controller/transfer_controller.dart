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

/// 转账页面的路由参数。
///
/// [walletId] 用于从安全存储读取当前钱包私钥，[asset] 描述本次转账的链、
/// 币种、余额、合约地址和精度信息。页面不再自行推断币种，避免链切换时
/// 出现资产和私钥不匹配。
class TransferPageArguments {
  const TransferPageArguments({required this.walletId, required this.asset});

  /// 当前执行转账的钱包 ID。
  final String walletId;

  /// 用户从首页选择的待转出资产。
  final ChainBalance asset;
}

/// 转账页面控制器。
///
/// 负责输入校验、手续费预估、钱包密码解锁、交易签名提交和交易哈希复制。
/// 真正的链上交易构造由 [WalletTransferService] 完成，控制器只协调 UI 状态
/// 与本地加密私钥读取。
class TransferController extends BaseController {
  TransferController({
    WalletTransferService? transferService,
    WalletRepository? repository,
  }) : _transferService = transferService ?? WalletTransferService(),
       _repository = repository ?? WalletRepository();

  final WalletTransferService _transferService;
  final WalletRepository _repository;

  /// 收款地址输入框控制器。
  final TextEditingController addressController = TextEditingController();

  /// 转账金额输入框控制器。
  final TextEditingController amountController = TextEditingController();

  /// 当前页面接收到的转账参数。
  TransferPageArguments? arguments;

  /// 是否正在提交交易，提交期间会禁用表单和按钮。
  bool isSubmitting = false;

  /// 是否正在实时查询手续费。
  bool isEstimatingFee = false;

  /// 手续费查询是否失败，用于 UI 展示降级提示。
  bool feeEstimateUnavailable = false;

  /// 最近一次成功获取的手续费估算。
  TransferFeeEstimate? feeEstimate;

  /// 链上广播后返回的交易哈希。
  String transactionHash = '';

  /// 手续费查询防抖计时器，避免输入过程中频繁请求 RPC。
  Timer? _feeDebounce;

  /// 手续费请求序号，用于忽略过期异步响应。
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

  /// 校验当前地址和金额输入是否能进入提交流程。
  ///
  /// 金额会按资产精度转换为链上最小单位，地址会根据链类型分别使用
  /// EVM、TRON 或 Solana 的格式校验。
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

  /// 解锁当前钱包并提交交易。
  ///
  /// Solana 需要额外读取 32 字节 seed 作为签名私钥；EVM 和 TRON 复用
  /// 十六进制私钥。异常会被转换成用户可理解的 toast。
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

  /// 根据链类型校验收款地址格式。
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

  /// 延迟触发手续费估算，减少用户输入时的 RPC 请求量。
  void _scheduleFeeEstimate() {
    _feeDebounce?.cancel();
    _feeDebounce = Timer(const Duration(milliseconds: 500), estimateFee);
  }

  /// 根据当前输入实时估算链上手续费。
  ///
  /// EVM 会走 gas price/estimateGas，TRON 会估算带宽/能量，Solana 当前展示
  /// 签名费兜底估算。请求返回时会通过 [_feeRequestId] 丢弃旧响应。
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

  /// 复制已提交交易的哈希。
  void copyTransactionHash() {
    if (transactionHash.isEmpty) return;
    Clipboard.setData(ClipboardData(text: transactionHash));
    Toast.show(S.current.copied);
  }

  /// 返回首页，并把是否已提交交易作为结果传回首页用于刷新余额。
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
