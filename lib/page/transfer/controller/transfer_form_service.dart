import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/payment_request.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../../../wallet/services/wallet_transfer_service.dart';
import 'transfer_asset_utils.dart';
import 'transfer_balance_validator.dart';
import 'transfer_input_validator.dart';
import 'transfer_scan_address_parser.dart';

/// 转账表单领域服务。
///
/// 只处理输入、资产匹配和金额计算，不依赖 Flutter 控件或页面提示。
class TransferFormService {
  TransferPaymentRequestResolution resolvePaymentRequest({
    required String rawValue,
    required ChainBalance currentAsset,
    required List<ChainBalance> availableAssets,
    required String existingAmount,
  }) {
    final request = TransferScanAddressParser.parse(
      rawValue,
      currentAsset.chainConfig ?? currentAsset.chain?.config,
    );
    if (request == null) {
      throw const TransferFormException(TransferFormFailure.invalidRequest);
    }

    final targetChainId = request.chainId ?? currentAsset.chainId;
    final chainAssets = assetsForChain(availableAssets, targetChainId);
    if (chainAssets.isEmpty) {
      throw TransferFormException(
        TransferFormFailure.networkUnavailable,
        detail: targetChainId,
      );
    }
    final targetAsset = _assetForPaymentRequest(
      request,
      chainAssets,
      current: currentAsset,
    );
    if (targetAsset == null) {
      throw TransferFormException(
        TransferFormFailure.assetUnavailable,
        detail: request.symbol ?? request.contractAddress ?? targetChainId,
      );
    }
    try {
      TransferInputValidator.validateAddress(targetAsset, request.address);
      if (request.amount != null) {
        WalletTransferService.amountToRawUnits(
          request.amount!,
          targetAsset.decimals,
        );
      }
    } catch (_) {
      throw const TransferFormException(TransferFormFailure.invalidRequest);
    }

    return TransferPaymentRequestResolution(
      request: request,
      currentAsset: currentAsset,
      targetAsset: targetAsset,
      existingAmount: existingAmount,
    );
  }

  List<ChainBalance> assetsForChain(
    List<ChainBalance> availableAssets,
    String chainId,
  ) {
    return availableAssets
        .where((asset) => asset.chainId == chainId)
        .toList(growable: false);
  }

  TransferFormValidation validateInput({
    required ChainBalance asset,
    required List<ChainBalance> availableAssets,
    required String address,
    required String amount,
    required TransferFeeEstimate? feeEstimate,
  }) {
    try {
      WalletTransferService.amountToRawUnits(amount, asset.decimals);
      TransferInputValidator.validateAddress(asset, address);
      final result = TransferBalanceValidator.validate(
        asset: asset,
        nativeAsset: _nativeAssetFor(asset, availableAssets),
        amount: amount,
        feeEstimate: feeEstimate,
      );
      return TransferFormValidation(balanceFailure: result.failure);
    } catch (_) {
      return const TransferFormValidation(invalidInput: true);
    }
  }

  TransferMaximumAmountResult maximumTransferAmount({
    required ChainBalance asset,
    required TransferFeeEstimate? feeEstimate,
  }) {
    return TransferBalanceValidator.maximumTransferAmount(
      asset: asset,
      feeEstimate: feeEstimate,
    );
  }

  ChainBalance? nativeAssetFor(
    ChainBalance asset,
    List<ChainBalance> balances,
  ) => _nativeAssetFor(asset, balances);

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

  ChainBalance? _assetForPaymentRequest(
    PaymentRequest request,
    List<ChainBalance> chainAssets, {
    required ChainBalance current,
  }) {
    final contract = request.contractAddress?.trim();
    if (contract != null && contract.isNotEmpty) {
      final requestedContract = _normalizedContract(
        chainAssets.first.chainRef,
        contract,
      );
      for (final asset in chainAssets) {
        final candidate = asset.contractAddress?.trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            _normalizedContract(asset.chainRef, candidate) ==
                requestedContract) {
          return asset;
        }
      }
      return null;
    }
    final symbol = request.symbol?.trim();
    if (symbol != null && symbol.isNotEmpty) {
      for (final asset in chainAssets) {
        if (asset.symbol.toUpperCase() == symbol.toUpperCase()) return asset;
      }
      return null;
    }
    if (current.chainId == chainAssets.first.chainId) return current;
    for (final asset in chainAssets) {
      if (asset.isNative) return asset;
    }
    return null;
  }

  String _normalizedContract(WalletChainRef chain, String contract) {
    return chain.isEvm ? contract.toLowerCase() : contract;
  }
}

class TransferFormValidation {
  const TransferFormValidation({
    this.invalidInput = false,
    this.balanceFailure,
  });

  final bool invalidInput;
  final TransferBalanceFailure? balanceFailure;

  bool get isValid => !invalidInput && balanceFailure == null;
}

enum TransferFormFailure {
  invalidRequest,
  networkUnavailable,
  assetUnavailable,
}

class TransferFormException implements Exception {
  const TransferFormException(this.failure, {this.detail});

  final TransferFormFailure failure;
  final String? detail;
}

/// 页面使用的付款请求匹配结果。
class TransferPaymentRequestResolution {
  const TransferPaymentRequestResolution({
    required this.request,
    required this.currentAsset,
    required this.targetAsset,
    required this.existingAmount,
  });

  final PaymentRequest request;
  final ChainBalance currentAsset;
  final ChainBalance targetAsset;
  final String existingAmount;

  bool get requiresNetworkSwitch => currentAsset.chainId != targetAsset.chainId;

  bool get requiresAssetSwitch => requiresNetworkSwitch
      ? currentAsset.symbol.toUpperCase() != targetAsset.symbol.toUpperCase()
      : TransferAssetUtils.assetKey(currentAsset) !=
            TransferAssetUtils.assetKey(targetAsset);

  bool get overwritesAmount =>
      request.amount != null &&
      existingAmount.isNotEmpty &&
      existingAmount != request.amount;
}
