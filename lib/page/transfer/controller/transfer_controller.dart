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
/// [walletId] 用于从安全存储读取当前钱包私钥，[asset] 描述从首页进入时
/// 默认选中的资产，[assets] 则提供页面内可切换的资产范围。
class TransferPageArguments {
  const TransferPageArguments({
    required this.walletId,
    required this.asset,
    this.assets = const [],
  });

  /// 当前执行转账的钱包 ID。
  final String walletId;

  /// 用户从首页选择的默认待转出资产。
  final ChainBalance asset;

  /// 允许在转账页内切换的资产列表。
  ///
  /// 一般由首页的可见资产列表传入；为空时会退化为只允许当前 [asset]。
  final List<ChainBalance> assets;
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

  /// 当前页面允许切换的资产列表。
  ///
  /// 这里保存的是首页已经查询好的余额数据，避免进入转账页后再次请求余额。
  List<ChainBalance> availableAssets = [];

  /// 当前选中的转账资产。
  ChainBalance? selectedAsset;

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
      _applyArguments(value);
      addressController.addListener(_scheduleFeeEstimate);
      amountController.addListener(_scheduleFeeEstimate);
    }
  }

  /// 当前真正用于展示、校验、估算手续费和提交交易的资产。
  ChainBalance? get currentAsset => selectedAsset ?? arguments?.asset;

  /// 当前可切换的链列表。
  ///
  /// 按 [WalletChain.values] 的固定顺序输出，避免 UI 顺序因为余额列表顺序变化
  /// 而跳动。
  List<WalletChain> get availableChains {
    final chainSet = availableAssets.map((asset) => asset.chain).toSet();
    return WalletChain.values
        .where((chain) => chainSet.contains(chain))
        .toList(growable: false);
  }

  /// 返回当前链下可选的转账资产。
  List<ChainBalance> assetsForSelectedChain() {
    final chain = currentAsset?.chain;
    if (chain == null) return const [];
    return assetsForChain(chain);
  }

  /// 返回指定链下可选的转账资产。
  List<ChainBalance> assetsForChain(WalletChain chain) {
    return availableAssets
        .where((asset) => asset.chain == chain)
        .toList(growable: false);
  }

  /// 切换转账链，并自动选中该链第一个可用资产。
  ///
  /// 切链会影响地址格式、手续费币种和余额展示，因此需要清掉旧手续费估算和
  /// 已提交交易哈希，再根据当前输入重新触发估算。
  void selectChain(WalletChain chain) {
    if (currentAsset?.chain == chain || isSubmitting) return;
    final assets = assetsForChain(chain);
    if (assets.isEmpty) return;
    selectedAsset = assets.first;
    _resetEstimateAndSubmittedState();
    update();
    _scheduleFeeEstimate();
  }

  /// 切换当前链下的转账币种。
  void selectAsset(ChainBalance asset) {
    if (isSubmitting) return;
    final current = currentAsset;
    if (current != null && _assetKey(current) == _assetKey(asset)) return;
    selectedAsset = asset;
    _resetEstimateAndSubmittedState();
    update();
    _scheduleFeeEstimate();
  }

  /// 校验当前地址和金额输入是否能进入提交流程。
  ///
  /// 金额会按资产精度转换为链上最小单位，地址会根据链类型分别使用
  /// EVM、TRON 或 Solana 的格式校验。
  bool validateTransferInput() {
    final asset = currentAsset;
    if (asset == null) return false;

    try {
      WalletTransferService.amountToRawUnits(
        amountController.text.trim(),
        asset.decimals,
      );
      _validateAddress(asset, addressController.text.trim());
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
    final asset = currentAsset;
    if (args == null || asset == null || isSubmitting) return;
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
      final solanaPrivateKey = asset.chain == WalletChain.solana
          ? await _repository.readWalletSolanaPrivateKey(
              walletId: args.walletId,
              password: password,
            )
          : null;
      final hash = await _transferService.transfer(
        privateKeyHex: privateKeyHex,
        asset: asset,
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
      WalletTransferService.amountToRawUnits(amount, asset.decimals);
      _validateAddress(asset, address);
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
        asset: asset,
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

  /// 初始化路由参数，并整理页面内可切换资产列表。
  void _applyArguments(TransferPageArguments value) {
    arguments = value;
    availableAssets = _deduplicateAssets(
      value.assets.isEmpty ? [value.asset] : [...value.assets, value.asset],
    );
    selectedAsset = availableAssets.firstWhere(
      (asset) => _assetKey(asset) == _assetKey(value.asset),
      orElse: () => value.asset,
    );
  }

  /// 去重资产列表。
  ///
  /// 同一条链上的同一合约只保留一条，避免下拉框出现重复币种。
  List<ChainBalance> _deduplicateAssets(List<ChainBalance> assets) {
    final keys = <String>{};
    final result = <ChainBalance>[];
    for (final asset in assets) {
      if (keys.add(_assetKey(asset))) {
        result.add(asset);
      }
    }
    return result;
  }

  /// 清理和当前资产强相关的临时状态。
  void _resetEstimateAndSubmittedState() {
    _feeDebounce?.cancel();
    _feeRequestId++;
    feeEstimate = null;
    feeEstimateUnavailable = false;
    isEstimatingFee = false;
    transactionHash = '';
  }

  /// 构建资产唯一 key。
  String _assetKey(ChainBalance asset) {
    final contract = asset.contractAddress?.trim() ?? '';
    final normalizedContract = asset.chain.isEvm
        ? contract.toLowerCase()
        : contract;
    return [
      asset.chain.id,
      normalizedContract.isEmpty ? 'native' : normalizedContract,
      asset.symbol.toUpperCase(),
    ].join(':');
  }

  @override
  void onClose() {
    _feeDebounce?.cancel();
    addressController.dispose();
    amountController.dispose();
    super.onClose();
  }
}
