import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:decimal/decimal.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/toast_util.dart';
import '../../browser/controller/block_explorer_controller.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/transaction/wallet_block_explorer_service.dart';
import '../../../wallet/services/crypto/wallet_secret_store.dart';
import '../../../wallet/services/wallet_transfer_service.dart';
import 'transfer_asset_utils.dart';
import 'transfer_balance_validator.dart';
import 'transfer_execution_service.dart';
import 'transfer_form_service.dart';
import 'transfer_input_validator.dart';
import 'transfer_page_state.dart';
import 'transfer_status_tracker.dart';
import 'transfer_review_use_case.dart';

/// 转账页面的路由参数。
///
/// [walletId] 用于从安全存储读取当前钱包私钥，[asset] 描述从首页进入时
/// 默认选中的资产，[assets] 则提供页面内可切换的资产范围。
class TransferPageArguments {
  const TransferPageArguments({
    required this.walletId,
    required this.walletName,
    required this.asset,
    this.assets = const [],
    this.usdPrices = const {},
  });

  /// 当前执行转账的钱包 ID。
  final String walletId;

  /// 发起转账的钱包名称，用于确认页展示真实来源。
  final String walletName;

  /// 用户从首页选择的默认待转出资产。
  final ChainBalance asset;

  /// 允许在转账页内切换的资产列表。
  ///
  /// 一般由首页的可见资产列表传入；为空时会退化为只允许当前 [asset]。
  final List<ChainBalance> assets;

  /// 首页最近一次可信 USD 单价，key 为大写币种符号。
  final Map<String, Decimal> usdPrices;
}

/// 转账页面控制器。
///
/// 负责输入校验、手续费预估、钱包密码解锁、交易签名提交和交易哈希复制。
/// 真正的链上交易构造由 [WalletTransferService] 完成，控制器只协调 UI 状态
/// 与本地加密私钥读取。
class TransferController extends BaseController {
  TransferController({
    TransferExecutionService? executionService,
    WalletBlockExplorerService? blockExplorerService,
    TransferStatusTracker? statusTracker,
    TransferReviewUseCase? reviewUseCase,
  }) : _executionService = executionService ?? TransferExecutionService(),
       _blockExplorerService =
           blockExplorerService ?? WalletBlockExplorerService(),
       _statusTracker = statusTracker ?? TransferStatusTracker(),
       _reviewUseCase =
           reviewUseCase ??
           TransferReviewUseCase(executionService: executionService);

  final TransferExecutionService _executionService;
  final TransferFormService _formService = TransferFormService();
  final TransferPageState _state = TransferPageState();
  final TransferReviewUseCase _reviewUseCase;
  final WalletBlockExplorerService _blockExplorerService;
  final TransferStatusTracker _statusTracker;

  /// 收款地址输入框控制器。
  final TextEditingController addressController = TextEditingController();

  /// 转账金额输入框控制器。
  final TextEditingController amountController = TextEditingController();

  TransferPageArguments? get arguments => _state.arguments;
  set arguments(TransferPageArguments? value) => _state.arguments = value;
  List<ChainBalance> get availableAssets => _state.availableAssets;
  set availableAssets(List<ChainBalance> value) =>
      _state.availableAssets = value;
  ChainBalance? get selectedAsset => _state.selectedAsset;
  set selectedAsset(ChainBalance? value) => _state.selectedAsset = value;
  bool get isSubmitting => _state.isSubmitting;
  set isSubmitting(bool value) => _state.isSubmitting = value;
  bool get isEstimatingFee => _state.isEstimatingFee;
  set isEstimatingFee(bool value) => _state.isEstimatingFee = value;
  bool get feeEstimateUnavailable => _state.feeEstimateUnavailable;
  set feeEstimateUnavailable(bool value) =>
      _state.feeEstimateUnavailable = value;
  TransferFeeEstimate? get feeEstimate => _state.feeEstimate;
  set feeEstimate(TransferFeeEstimate? value) => _state.feeEstimate = value;
  List<String> get recipientHistoryAddresses =>
      _state.recipientHistoryAddresses;
  set recipientHistoryAddresses(List<String> value) =>
      _state.recipientHistoryAddresses = value;
  String get transactionHash => _state.transactionHash;
  set transactionHash(String value) => _state.transactionHash = value;
  String? get scannedPaymentMemo => _state.scannedPaymentMemo;
  set scannedPaymentMemo(String? value) => _state.scannedPaymentMemo = value;
  String? get _paymentRequestAddress => _state.paymentRequestAddress;
  set _paymentRequestAddress(String? value) =>
      _state.paymentRequestAddress = value;
  WalletTransactionStatus get submittedStatus => _state.submittedStatus;
  set submittedStatus(WalletTransactionStatus value) =>
      _state.submittedStatus = value;

  /// 手续费查询防抖计时器，避免输入过程中频繁请求 RPC。
  Timer? _feeDebounce;

  /// 手续费请求序号，用于忽略过期异步响应。
  int _feeRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    final value = Get.arguments;
    if (value is TransferPageArguments) {
      _applyArguments(value);
      addressController.addListener(_handleAddressChanged);
      amountController.addListener(_scheduleFeeEstimate);
    }
  }

  /// 当前真正用于展示、校验、估算手续费和提交交易的资产。
  ChainBalance? get currentAsset => selectedAsset ?? arguments?.asset;

  /// 当前可切换的链列表。
  ///
  /// 按首页传入余额的链顺序输出，避免 UI 顺序因为资产列表去重而跳动。
  List<WalletChainConfig> get availableChains {
    final chainIds = availableAssets.map((asset) => asset.chainId).toSet();
    return availableAssets
        .map((asset) => asset.chainConfig ?? asset.chain!.config)
        .where((chain) => chainIds.remove(chain.id))
        .toList(growable: false);
  }

  /// 返回当前链下可选的转账资产。
  List<ChainBalance> assetsForSelectedChain() {
    final chain = currentAsset?.chainId;
    if (chain == null) return const [];
    return assetsForChain(chain);
  }

  /// 返回指定链下可选的转账资产。
  List<ChainBalance> assetsForChain(String chainId) {
    return availableAssets
        .where((asset) => asset.chainId == chainId)
        .toList(growable: false);
  }

  /// 切换转账链，并自动选中该链第一个可用资产。
  ///
  /// 切链会影响地址格式、手续费币种和余额展示，因此需要清掉旧手续费估算和
  /// 已提交交易哈希，再根据当前输入重新触发估算。
  void selectChain(WalletChainConfig chain) {
    if (currentAsset?.chainId == chain.id || isSubmitting) return;
    final assets = assetsForChain(chain.id);
    if (assets.isEmpty) return;
    selectedAsset = assets.first;
    _clearPaymentRequestMetadata();
    _resetEstimateAndSubmittedState();
    update();
    _scheduleFeeEstimate();
  }

  /// 切换当前链下的转账币种。
  void selectAsset(ChainBalance asset) {
    if (isSubmitting) return;
    final current = currentAsset;
    if (current != null &&
        TransferAssetUtils.assetKey(current) ==
            TransferAssetUtils.assetKey(asset)) {
      return;
    }
    selectedAsset = asset;
    _clearPaymentRequestMetadata();
    _resetEstimateAndSubmittedState();
    update();
    _scheduleFeeEstimate();
  }

  /// 解析并匹配扫码付款请求，但不修改当前表单。
  ///
  /// 调用方必须展示二次确认，并在用户同意后调用 [applyPaymentRequest]。链或 Token
  /// 不匹配时会解析到目标资产，找不到对应链/资产则直接拒绝。
  PaymentRequestResolution? resolvePaymentRequest(String rawValue) {
    final current = currentAsset;
    if (current == null) return null;
    try {
      return _formService.resolvePaymentRequest(
        rawValue: rawValue,
        currentAsset: current,
        availableAssets: availableAssets,
        existingAmount: amountController.text.trim(),
      );
    } on TransferFormException catch (error) {
      switch (error.failure) {
        case TransferFormFailure.invalidRequest:
          Toast.show(S.current.paymentRequestInvalid);
        case TransferFormFailure.networkUnavailable:
          Toast.show(S.current.paymentRequestNetworkUnavailable(error.detail!));
        case TransferFormFailure.assetUnavailable:
          Toast.show(S.current.paymentRequestAssetUnavailable(error.detail!));
      }
      return null;
    }
  }

  /// 将用户已确认的付款请求应用到转账表单。
  void applyPaymentRequest(PaymentRequestResolution resolution) {
    if (isSubmitting) return;
    selectedAsset = resolution.targetAsset;
    _resetEstimateAndSubmittedState();
    final request = resolution.request;
    _paymentRequestAddress = request.address;
    scannedPaymentMemo = request.memo;
    addressController.text = request.address;
    addressController.selection = TextSelection.collapsed(
      offset: request.address.length,
    );
    final requestedAmount = request.amount;
    if (requestedAmount != null) {
      amountController.text = requestedAmount;
      amountController.selection = TextSelection.collapsed(
        offset: requestedAmount.length,
      );
    }
    update();
    _scheduleFeeEstimate();
  }

  /// 将地址簿选择的地址写入收款地址输入框。
  void fillRecipientAddressFromBook(String address) {
    final value = address.trim();
    if (value.isEmpty) return;
    addressController.text = value;
    addressController.selection = TextSelection.collapsed(offset: value.length);
    transactionHash = '';
    scannedPaymentMemo = null;
    update();
    _scheduleFeeEstimate();
  }

  void _handleAddressChanged() {
    final requestAddress = _paymentRequestAddress;
    if (requestAddress != null &&
        addressController.text.trim() != requestAddress) {
      _clearPaymentRequestMetadata();
      update();
    }
    _scheduleFeeEstimate();
  }

  void _clearPaymentRequestMetadata() {
    _paymentRequestAddress = null;
    scannedPaymentMemo = null;
  }

  /// 校验当前地址和金额输入是否能进入提交流程。
  ///
  /// 金额会按资产精度转换为链上最小单位，地址会根据链类型分别使用
  /// EVM、TRON 或 Solana 的格式校验。
  bool validateTransferInput() {
    final asset = currentAsset;
    if (asset == null) return false;

    final result = _formService.validateInput(
      asset: asset,
      availableAssets: availableAssets,
      address: addressController.text.trim(),
      amount: amountController.text.trim(),
      feeEstimate: feeEstimate,
    );
    if (result.invalidInput) {
      Toast.show(S.current.transferInputInvalid);
      return false;
    }
    if (!result.isValid) {
      _showBalanceValidationFailure(result.balanceFailure!, asset);
      return false;
    }
    return true;
  }

  /// 将当前资产的安全最大可转金额写入输入框。
  ///
  /// Token 使用完整 Token 余额；原生币会先扣除当前预估手续费，避免“全部”
  /// 转出后没有余额支付网络费用。
  void fillMaximumAmount() {
    final asset = currentAsset;
    if (asset == null || isSubmitting) return;
    final result = _formService.maximumTransferAmount(
      asset: asset,
      feeEstimate: feeEstimate,
    );
    if (!result.isValid) {
      _showBalanceValidationFailure(result.failure!, asset);
      return;
    }
    final amount = result.amount!;
    amountController.text = amount;
    amountController.selection = TextSelection.collapsed(offset: amount.length);
  }

  /// 在打开交易确认页前刷新余额和费用，并冻结本次 EVM 交易草稿。
  ///
  /// 用户在确认页看到的 EVM 最大手续费、nonce 和 Gas 参数会由 [submit] 原样复用，
  /// 不会在密码确认后悄悄切换到另一套签名参数。
  Future<bool> prepareTransferReview() async {
    final asset = currentAsset;
    if (asset == null || isSubmitting || !validateTransferInput()) {
      return false;
    }
    _feeDebounce?.cancel();
    _feeRequestId++;
    isSubmitting = true;
    isEstimatingFee = true;
    update();
    try {
      final args = arguments;
      if (args == null) return false;
      final preparation = await _reviewUseCase.prepare(
        walletId: args.walletId,
        asset: asset,
        availableAssets: availableAssets,
        recipientAddress: addressController.text.trim(),
        amount: amountController.text.trim(),
      );
      final preflight = preparation.preflight;
      feeEstimate = preflight.fee;
      _replaceChainBalances(preflight.asset.chainId, preflight.balances);
      selectedAsset = preflight.asset;
      recipientHistoryAddresses = preparation.recipientHistoryAddresses;
      update();
      return true;
    } on TransferExecutionException catch (error) {
      _showPreflightFailure(error, asset);
      return false;
    } catch (_) {
      Toast.show(S.current.transferBalanceRefreshFailed);
      return false;
    } finally {
      isSubmitting = false;
      isEstimatingFee = false;
      update();
    }
  }

  /// 解锁当前钱包并提交交易。
  ///
  /// Solana 需要额外读取 32 字节 seed；Bitcoin 助记词钱包读取 BIP84 派生私钥；
  /// EVM 和 TRON 复用基础十六进制私钥。异常会被转换成用户可理解的 toast。
  Future<void> submit(String password) async {
    final args = arguments;
    final asset = currentAsset;
    if (args == null || asset == null || isSubmitting) return;
    if (!validateTransferInput()) return;
    if (password.isEmpty) {
      Toast.show(S.current.walletPasswordRequired);
      return;
    }
    if (asset.chainRef.isEvm && feeEstimate?.evmDraft == null) {
      Toast.show(S.current.transferFeeRequired);
      return;
    }

    try {
      isSubmitting = true;
      transactionHash = '';
      submittedStatus = WalletTransactionStatus.unknown;
      update();
      final confirmedEvmFee = asset.chainRef.isEvm ? feeEstimate : null;
      final result = await _executionService.submit(
        walletId: args.walletId,
        password: password,
        asset: asset,
        recipientAddress: addressController.text.trim(),
        amount: amountController.text.trim(),
        confirmedEvmFee: confirmedEvmFee,
      );
      final verifiedAsset = result.preflight.asset;
      feeEstimate = result.preflight.fee;
      _replaceChainBalances(verifiedAsset.chainId, result.preflight.balances);
      selectedAsset = verifiedAsset;
      final hash = result.transactionHash;
      transactionHash = hash;
      submittedStatus = WalletTransactionStatus.pending;
      final submission = _submissionContext(verifiedAsset, hash);
      await _statusTracker.saveSubmittedTransaction(submission);
      _statusTracker.start(
        submission,
        onStatusChanged: _handleSubmittedStatusChanged,
      );
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

  void _showPreflightFailure(
    TransferExecutionException error,
    ChainBalance asset,
  ) {
    if (error.failure ==
        TransferExecutionFailure.customAssetMetadataUnavailable) {
      Toast.show(S.current.customAssetMetadataUnavailable);
    } else if (error.failure == TransferExecutionFailure.balanceValidation) {
      final failure = error.balanceFailure;
      if (failure != null) {
        _showBalanceValidationFailure(failure, asset);
      } else {
        Toast.show(S.current.transferBalanceRefreshFailed);
      }
    } else if (error.failure == TransferExecutionFailure.feeUnavailable) {
      Toast.show(S.current.transferFeeRequired);
    } else {
      Toast.show(S.current.transferBalanceRefreshFailed);
    }
  }

  ChainBalance? _nativeAssetFor(
    ChainBalance asset,
    List<ChainBalance> balances,
  ) {
    if (asset.isNative) return asset;
    for (final candidate in balances) {
      if (candidate.chainId == asset.chainId && candidate.isNative) {
        return candidate;
      }
    }
    return null;
  }

  void _replaceChainBalances(String chainId, List<ChainBalance> freshBalances) {
    final refreshedByKey = {
      for (final balance in freshBalances)
        TransferAssetUtils.assetKey(balance): balance,
    };
    final merged = availableAssets.map((balance) {
      if (balance.chainId != chainId) return balance;
      return refreshedByKey.remove(TransferAssetUtils.assetKey(balance)) ??
          balance;
    }).toList();
    merged.addAll(refreshedByKey.values);
    availableAssets = TransferAssetUtils.deduplicateAssets(merged);
  }

  void _showBalanceValidationFailure(
    TransferBalanceFailure failure,
    ChainBalance asset,
  ) {
    switch (failure) {
      case TransferBalanceFailure.insufficientAssetBalance:
        Toast.show(S.current.transferBalanceInsufficient(asset.symbol));
      case TransferBalanceFailure.insufficientNativeFeeBalance:
        final nativeSymbol =
            _nativeAssetFor(asset, availableAssets)?.symbol ??
            feeEstimate?.symbol ??
            asset.chainRef.symbol;
        Toast.show(
          S.current.transferNativeFeeBalanceInsufficient(nativeSymbol),
        );
      case TransferBalanceFailure.feeUnavailable:
        Toast.show(S.current.transferFeeRequired);
      case TransferBalanceFailure.assetBalanceUnavailable:
      case TransferBalanceFailure.nativeBalanceUnavailable:
        Toast.show(S.current.transferBalanceRefreshFailed);
    }
  }

  /// 延迟触发手续费估算，减少用户输入时的 RPC 请求量。
  void _scheduleFeeEstimate() {
    _feeDebounce?.cancel();
    _feeDebounce = Timer(const Duration(milliseconds: 500), estimateFee);
  }

  /// 根据当前输入实时估算链上手续费。
  ///
  /// EVM 会生成包含 pending nonce、Gas 和费用参数的完整草稿，TRON 会估算
  /// 带宽/能量，Solana 当前展示签名费兜底估算。请求返回时会通过
  /// [_feeRequestId] 丢弃旧响应。
  Future<void> estimateFee() async {
    final asset = currentAsset;
    if (asset == null) return;

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
      if (!TransferInputValidator.canEstimateFee(
        asset: asset,
        address: address,
        amount: amount,
      )) {
        Toast.show(S.current.transferFailed);
        feeEstimate = null;
        feeEstimateUnavailable = false;
        isEstimatingFee = false;
        update();
        return;
      }
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
      final estimate = await _executionService.estimateFee(
        asset: asset,
        recipientAddress: address,
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

  Future<void> openSubmittedTransactionExplorer() async {
    final asset = currentAsset;
    if (asset == null || transactionHash.isEmpty) return;
    final uri = _blockExplorerService.transactionUri(asset, transactionHash);
    if (uri == null) {
      Toast.show(S.current.blockExplorerUnavailable);
      return;
    }
    await Get.toNamed(
      RouteTable.blockExplorer,
      arguments: BlockExplorerPageArguments(
        url: uri,
        title: asset.chainRef.name,
      ),
    );
  }

  Future<void> refreshSubmittedStatus() async {
    final asset = currentAsset;
    final hash = transactionHash;
    if (asset == null || hash.isEmpty) return;
    try {
      final status = await _statusTracker.refreshStatus(
        _submissionContext(asset, hash),
      );
      submittedStatus = status;
      update();
    } catch (_) {
      Toast.show(S.current.transactionStatusRefreshFailed);
    }
  }

  /// 返回首页，并把是否已提交交易作为结果传回首页用于刷新余额。
  void backToWallet() {
    Get.back(result: transactionHash.isNotEmpty);
  }

  /// 初始化路由参数，并整理页面内可切换资产列表。
  void _applyArguments(TransferPageArguments value) {
    arguments = value;
    availableAssets = TransferAssetUtils.deduplicateAssets(
      value.assets.isEmpty ? [value.asset] : [...value.assets, value.asset],
    );
    selectedAsset = availableAssets.firstWhere(
      (asset) =>
          TransferAssetUtils.assetKey(asset) ==
          TransferAssetUtils.assetKey(value.asset),
      orElse: () => value.asset,
    );
  }

  /// 清理和当前资产强相关的临时状态。
  void _resetEstimateAndSubmittedState() {
    _feeDebounce?.cancel();
    _feeRequestId++;
    feeEstimate = null;
    feeEstimateUnavailable = false;
    isEstimatingFee = false;
    recipientHistoryAddresses = const [];
    transactionHash = '';
    submittedStatus = WalletTransactionStatus.unknown;
    _statusTracker.stop();
  }

  TransferSubmissionContext _submissionContext(
    ChainBalance asset,
    String hash,
  ) {
    return TransferSubmissionContext(
      walletId: arguments!.walletId,
      asset: asset,
      txHash: hash,
      recipientAddress: addressController.text.trim(),
      amount: amountController.text.trim(),
      feeAmount: feeEstimate?.amount,
      feeSymbol: feeEstimate?.symbol,
    );
  }

  Future<void> _handleSubmittedStatusChanged(
    WalletTransactionStatus status,
  ) async {
    if (transactionHash.isEmpty) return;
    submittedStatus = status;
    update();
  }

  @override
  void onClose() {
    _feeDebounce?.cancel();
    _statusTracker.dispose();
    addressController.dispose();
    amountController.dispose();
    super.onClose();
  }
}

/// 保持页面和测试的既有类型名，实际实现位于表单领域服务。
typedef PaymentRequestResolution = TransferPaymentRequestResolution;

/// 扫码付款请求与当前表单资产的匹配结果。
