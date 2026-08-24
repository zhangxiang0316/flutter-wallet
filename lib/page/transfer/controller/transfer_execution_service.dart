import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/models/wallet_chain_extensions.dart';
import '../../../wallet/services/chain_balance_service.dart';
import '../../../wallet/services/config/wallet_custom_asset_service.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/wallet_transfer_service.dart';
import 'transfer_asset_utils.dart';
import 'transfer_balance_validator.dart';

/// 转账提交前的完整链上预检结果。
class TransferPreflightResult {
  const TransferPreflightResult({
    required this.asset,
    required this.nativeAsset,
    required this.balances,
    required this.fee,
  });

  final ChainBalance asset;
  final ChainBalance nativeAsset;
  final List<ChainBalance> balances;
  final TransferFeeEstimate fee;
}

/// 转账执行服务。
///
/// 将转账页面中与链上执行相关的编排集中到领域服务：余额预检、Token 元数据
/// 校验、手续费估算、密钥材料读取和交易广播。该服务不依赖 Flutter UI，不负责
/// Toast 或页面状态更新。
class TransferExecutionService {
  TransferExecutionService({
    WalletTransferService? transferService,
    WalletRepository? repository,
    ChainBalanceService? balanceService,
    WalletCustomAssetService? customAssetService,
  }) : _transferService = transferService ?? WalletTransferService(),
       _repository = repository ?? WalletRepository(),
       _balanceService = balanceService ?? ChainBalanceService(),
       _customAssetService = customAssetService ?? WalletCustomAssetService();

  final WalletTransferService _transferService;
  final WalletRepository _repository;
  final ChainBalanceService _balanceService;
  final WalletCustomAssetService _customAssetService;

  /// 估算输入中的交易手续费。
  Future<TransferFeeEstimate> estimateFee({
    required ChainBalance asset,
    required String recipientAddress,
    required String amount,
  }) {
    return _transferService.estimateFee(
      asset: asset,
      toAddress: recipientAddress,
      amount: amount,
    );
  }

  /// 刷新余额、验证资产元数据、估算手续费并执行余额校验。
  Future<TransferPreflightResult> refreshPreflight({
    required ChainBalance asset,
    required String recipientAddress,
    required String amount,
    TransferFeeEstimate? confirmedEvmFee,
  }) async {
    final chain = asset.chainConfig ?? asset.chain!.config;
    if (asset.chainRef.isEvm && !asset.isNative) {
      final decimalsVerified = await _customAssetService.verifyEvmTokenDecimals(
        chain: chain,
        contractAddress: asset.contractAddress!,
        expectedDecimals: asset.decimals,
      );
      if (!decimalsVerified) {
        throw const TransferExecutionException(
          TransferExecutionFailure.customAssetMetadataUnavailable,
        );
      }
    }

    late final List<ChainBalance> balances;
    try {
      balances = await _balanceService.loadChainBalances(
        chain: chain,
        address: asset.address,
      );
    } catch (_) {
      throw const TransferExecutionException(
        TransferExecutionFailure.balanceUnavailable,
      );
    }
    final assetKey = TransferAssetUtils.assetKey(asset);
    final refreshedAsset = balances.cast<ChainBalance?>().firstWhere(
      (candidate) =>
          candidate != null &&
          TransferAssetUtils.assetKey(candidate) == assetKey,
      orElse: () => null,
    );
    if (refreshedAsset == null) {
      throw const TransferExecutionException(
        TransferExecutionFailure.balanceUnavailable,
      );
    }

    final nativeAsset = _nativeAssetFor(refreshedAsset, balances);
    if (refreshedAsset.hasError ||
        nativeAsset == null ||
        nativeAsset.hasError) {
      throw const TransferExecutionException(
        TransferExecutionFailure.balanceUnavailable,
      );
    }

    late final TransferFeeEstimate fee;
    try {
      fee =
          confirmedEvmFee ??
          await _transferService.estimateFee(
            asset: refreshedAsset,
            toAddress: recipientAddress,
            amount: amount,
          );
    } catch (_) {
      throw const TransferExecutionException(
        TransferExecutionFailure.feeUnavailable,
      );
    }
    final validation = TransferBalanceValidator.validate(
      asset: refreshedAsset,
      nativeAsset: nativeAsset,
      amount: amount,
      feeEstimate: fee,
    );
    if (!validation.isValid) {
      throw TransferExecutionException(
        TransferExecutionFailure.balanceValidation,
        balanceFailure: validation.failure,
      );
    }

    return TransferPreflightResult(
      asset: refreshedAsset,
      nativeAsset: nativeAsset,
      balances: balances,
      fee: fee,
    );
  }

  /// 执行一次完整转账，并返回最终使用的预检结果和交易 hash。
  Future<({TransferPreflightResult preflight, String transactionHash})> submit({
    required String walletId,
    required String password,
    required ChainBalance asset,
    required String recipientAddress,
    required String amount,
    TransferFeeEstimate? confirmedEvmFee,
  }) async {
    final preflight = await refreshPreflight(
      asset: asset,
      recipientAddress: recipientAddress,
      amount: amount,
      confirmedEvmFee: confirmedEvmFee,
    );
    final privateKeyHex = await _repository.readWalletPrivateKey(
      walletId: walletId,
      password: password,
    );
    final verifiedAsset = preflight.asset;
    final bitcoinPrivateKey = verifiedAsset.chainRef.isBitcoin
        ? await _repository.readWalletBitcoinPrivateKey(
            walletId: walletId,
            password: password,
          )
        : null;
    final solanaPrivateKey = verifiedAsset.chainRef.isSolana
        ? await _repository.readWalletSolanaPrivateKey(
            walletId: walletId,
            password: password,
          )
        : null;
    final suiPrivateKey = verifiedAsset.chainRef.isSui
        ? await _repository.readWalletSuiPrivateKey(
            walletId: walletId,
            password: password,
          )
        : null;
    final aptosPrivateKey = verifiedAsset.chainRef.isAptos
        ? await _repository.readWalletAptosPrivateKey(
            walletId: walletId,
            password: password,
          )
        : null;

    final transactionHash = await _transferService.transfer(
      privateKeyHex: bitcoinPrivateKey ?? privateKeyHex,
      asset: verifiedAsset,
      toAddress: recipientAddress,
      amount: amount,
      solanaPrivateKey: solanaPrivateKey,
      suiPrivateKey: suiPrivateKey,
      aptosPrivateKey: aptosPrivateKey,
      evmDraft: preflight.fee.evmDraft,
    );
    return (preflight: preflight, transactionHash: transactionHash);
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
}

enum TransferExecutionFailure {
  customAssetMetadataUnavailable,
  balanceUnavailable,
  feeUnavailable,
  balanceValidation,
}

class TransferExecutionException implements Exception {
  const TransferExecutionException(this.failure, {this.balanceFailure});

  final TransferExecutionFailure failure;
  final TransferBalanceFailure? balanceFailure;
}
