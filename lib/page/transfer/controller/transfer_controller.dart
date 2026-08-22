import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/toast_util.dart';
import '../../browser/controller/block_explorer_controller.dart';
import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/models/wallet_chain_extensions.dart';
import '../../../wallet/models/wallet_transaction_record.dart';
import '../../../wallet/services/transaction/transaction_history_cache.dart';
import '../../../wallet/services/transaction/wallet_block_explorer_service.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/crypto/wallet_secret_store.dart';
import '../../../wallet/services/transaction/wallet_transaction_status_service.dart';
import '../../../wallet/services/chain_balance_service.dart';
import '../../../wallet/services/wallet_transfer_service.dart';
import 'transfer_asset_utils.dart';
import 'transfer_balance_validator.dart';
import 'transfer_input_validator.dart';
import 'transfer_scan_address_parser.dart';

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
    ChainBalanceService? balanceService,
    TransactionHistoryCache? transactionCache,
    WalletTransactionStatusService? transactionStatusService,
    WalletBlockExplorerService? blockExplorerService,
  }) : _transferService = transferService ?? WalletTransferService(),
       _repository = repository ?? WalletRepository(),
       _balanceService = balanceService ?? ChainBalanceService(),
       _transactionCache = transactionCache ?? TransactionHistoryCache(),
       _transactionStatusService =
           transactionStatusService ?? WalletTransactionStatusService(),
       _blockExplorerService =
           blockExplorerService ?? const WalletBlockExplorerService();

  final WalletTransferService _transferService;
  final WalletRepository _repository;
  final ChainBalanceService _balanceService;
  final TransactionHistoryCache _transactionCache;
  final WalletTransactionStatusService _transactionStatusService;
  final WalletBlockExplorerService _blockExplorerService;

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

  /// 当前提交交易的链上确认状态。
  WalletTransactionStatus submittedStatus = WalletTransactionStatus.unknown;

  /// 手续费查询防抖计时器，避免输入过程中频繁请求 RPC。
  Timer? _feeDebounce;

  Timer? _submittedStatusTimer;

  int _submittedStatusPollCount = 0;

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
    _resetEstimateAndSubmittedState();
    update();
    _scheduleFeeEstimate();
  }

  /// 将扫码结果写入收款地址输入框。
  ///
  /// 二维码可能只包含纯地址，也可能包含 `ethereum:0x...`、`tron:T...` 或
  /// `solana:<address>?amount=...` 这类 URI。这里会优先按当前链格式提取地址，
  /// 找不到时再退回到 URI/path/query 中的地址片段。
  void fillRecipientAddressFromScan(String rawValue) {
    final address = TransferScanAddressParser.extract(
      rawValue,
      currentAsset?.chainConfig ?? currentAsset?.chain?.config,
    );
    if (address == null || address.isEmpty) {
      Toast.show(S.current.scanNoAddressFound);
      return;
    }
    addressController.text = address;
    addressController.selection = TextSelection.collapsed(
      offset: address.length,
    );
    transactionHash = '';
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
      TransferInputValidator.validateAddress(
        asset,
        addressController.text.trim(),
      );
      final result = TransferBalanceValidator.validate(
        asset: asset,
        nativeAsset: _nativeAssetFor(asset, availableAssets),
        amount: amountController.text.trim(),
        feeEstimate: feeEstimate,
      );
      if (!result.isValid) {
        _showBalanceValidationFailure(result.failure!, asset);
        return false;
      }
    } catch (_) {
      Toast.show(S.current.transferInputInvalid);
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
    try {
      final result = TransferBalanceValidator.maximumTransferAmount(
        asset: asset,
        feeEstimate: feeEstimate,
      );
      if (!result.isValid) {
        _showBalanceValidationFailure(result.failure!, asset);
        return;
      }
      final amount = result.amount!;
      amountController.text = amount;
      amountController.selection = TextSelection.collapsed(
        offset: amount.length,
      );
    } catch (_) {
      Toast.show(S.current.transferBalanceRefreshFailed);
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

    try {
      isSubmitting = true;
      transactionHash = '';
      submittedStatus = WalletTransactionStatus.unknown;
      update();
      final preflight = await _refreshTransferPreflight(asset);
      if (preflight == null) return;
      final verifiedAsset = preflight.asset;
      var privateKeyHex = await _repository.readWalletPrivateKey(
        walletId: args.walletId,
        password: password,
      );
      if (verifiedAsset.chainRef.isBitcoin) {
        privateKeyHex = await _repository.readWalletBitcoinPrivateKey(
          walletId: args.walletId,
          password: password,
        );
      }
      final solanaPrivateKey = verifiedAsset.chainRef.isSolana
          ? await _repository.readWalletSolanaPrivateKey(
              walletId: args.walletId,
              password: password,
            )
          : null;
      final suiPrivateKey = verifiedAsset.chainRef.isSui
          ? await _repository.readWalletSuiPrivateKey(
              walletId: args.walletId,
              password: password,
            )
          : null;
      final aptosPrivateKey = verifiedAsset.chainRef.isAptos
          ? await _repository.readWalletAptosPrivateKey(
              walletId: args.walletId,
              password: password,
            )
          : null;
      final hash = await _transferService.transfer(
        privateKeyHex: privateKeyHex,
        asset: verifiedAsset,
        toAddress: addressController.text.trim(),
        amount: amountController.text.trim(),
        solanaPrivateKey: solanaPrivateKey,
        suiPrivateKey: suiPrivateKey,
        aptosPrivateKey: aptosPrivateKey,
      );
      transactionHash = hash;
      submittedStatus = WalletTransactionStatus.pending;
      await _saveSubmittedTransaction(verifiedAsset, hash);
      _startSubmittedStatusTracking(verifiedAsset, hash);
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

  /// 用户确认并输入密码后，再次刷新当前链余额和手续费。
  ///
  /// 该方法必须在读取私钥之前完成；任何余额缺失、RPC 查询失败或手续费不足
  /// 都会直接停止后续签名。
  Future<_TransferPreflight?> _refreshTransferPreflight(
    ChainBalance asset,
  ) async {
    final chain = asset.chainConfig ?? asset.chain!.config;
    late final List<ChainBalance> freshBalances;
    try {
      freshBalances = await _balanceService.loadChainBalances(
        chain: chain,
        address: asset.address,
      );
    } catch (_) {
      Toast.show(S.current.transferBalanceRefreshFailed);
      return null;
    }

    final assetKey = TransferAssetUtils.assetKey(asset);
    final refreshedAsset = freshBalances.cast<ChainBalance?>().firstWhere(
      (candidate) =>
          candidate != null &&
          TransferAssetUtils.assetKey(candidate) == assetKey,
      orElse: () => null,
    );
    if (refreshedAsset == null) {
      Toast.show(S.current.transferBalanceRefreshFailed);
      return null;
    }
    final refreshedNative = _nativeAssetFor(refreshedAsset, freshBalances);
    if (refreshedAsset.hasError ||
        refreshedNative == null ||
        refreshedNative.hasError) {
      Toast.show(S.current.transferBalanceRefreshFailed);
      return null;
    }

    late final TransferFeeEstimate freshFee;
    try {
      freshFee = await _transferService.estimateFee(
        asset: refreshedAsset,
        toAddress: addressController.text.trim(),
        amount: amountController.text.trim(),
      );
    } catch (_) {
      Toast.show(S.current.transferFeeRequired);
      return null;
    }

    final validation = TransferBalanceValidator.validate(
      asset: refreshedAsset,
      nativeAsset: refreshedNative,
      amount: amountController.text.trim(),
      feeEstimate: freshFee,
    );
    if (!validation.isValid) {
      _showBalanceValidationFailure(validation.failure!, refreshedAsset);
      return null;
    }

    feeEstimate = freshFee;
    _replaceChainBalances(chain.id, freshBalances);
    selectedAsset = refreshedAsset;
    update();
    return _TransferPreflight(asset: refreshedAsset);
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
      final status = await _transactionStatusService.loadStatus(
        chain: asset.chainRef,
        txHash: hash,
      );
      submittedStatus = status;
      await _saveSubmittedTransaction(asset, hash, status: status);
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
    transactionHash = '';
    submittedStatus = WalletTransactionStatus.unknown;
    _stopSubmittedStatusTracking();
  }

  Future<void> _saveSubmittedTransaction(
    ChainBalance asset,
    String txHash, {
    WalletTransactionStatus status = WalletTransactionStatus.pending,
  }) {
    final record = WalletTransactionRecord(
      id: _localRecordId(arguments!.walletId, asset, txHash),
      walletId: arguments!.walletId,
      chainId: asset.chainId,
      chainName: asset.chainRef.name,
      symbol: asset.symbol,
      assetName: asset.name,
      walletAddress: asset.address,
      txHash: txHash,
      fromAddress: asset.address,
      toAddress: addressController.text.trim(),
      amount: amountController.text.trim(),
      decimals: asset.decimals,
      direction: WalletTransactionDirection.outgoing,
      status: status,
      source: WalletTransactionSource.local,
      contractAddress: asset.contractAddress,
      feeAmount: feeEstimate?.amount,
      feeSymbol: feeEstimate?.symbol,
      timestamp: DateTime.now(),
    );
    return _transactionCache.upsertLocalRecord(record);
  }

  String _localRecordId(String walletId, ChainBalance asset, String txHash) {
    return [
      'local',
      walletId,
      asset.chainId,
      asset.contractAddress ?? 'native',
      txHash.toLowerCase(),
    ].join(':');
  }

  void _startSubmittedStatusTracking(ChainBalance asset, String txHash) {
    _stopSubmittedStatusTracking();
    _submittedStatusPollCount = 0;
    _submittedStatusTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollSubmittedStatus(asset, txHash);
    });
    _pollSubmittedStatus(asset, txHash);
  }

  Future<void> _pollSubmittedStatus(ChainBalance asset, String txHash) async {
    if (txHash != transactionHash) return;
    _submittedStatusPollCount++;
    try {
      final status = await _transactionStatusService.loadStatus(
        chain: asset.chainRef,
        txHash: txHash,
      );
      if (txHash != transactionHash) return;
      submittedStatus = status;
      await _saveSubmittedTransaction(asset, txHash, status: status);
      update();
      if (status != WalletTransactionStatus.pending) {
        _stopSubmittedStatusTracking();
      }
    } catch (_) {
      if (_submittedStatusPollCount >= 8) {
        _stopSubmittedStatusTracking();
      }
    }
  }

  void _stopSubmittedStatusTracking() {
    _submittedStatusTimer?.cancel();
    _submittedStatusTimer = null;
  }

  @override
  void onClose() {
    _feeDebounce?.cancel();
    _stopSubmittedStatusTracking();
    addressController.dispose();
    amountController.dispose();
    super.onClose();
  }
}

class _TransferPreflight {
  const _TransferPreflight({required this.asset});

  final ChainBalance asset;
}
