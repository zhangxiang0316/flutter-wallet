import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/services/wallet_transfer_service.dart';

/// 转账余额校验失败原因。
enum TransferBalanceFailure {
  feeUnavailable,
  assetBalanceUnavailable,
  nativeBalanceUnavailable,
  insufficientAssetBalance,
  insufficientNativeFeeBalance,
}

/// 转账前余额校验结果。
class TransferBalanceValidationResult {
  const TransferBalanceValidationResult._(this.failure);

  const TransferBalanceValidationResult.valid() : this._(null);

  const TransferBalanceValidationResult.invalid(TransferBalanceFailure failure)
    : this._(failure);

  final TransferBalanceFailure? failure;

  bool get isValid => failure == null;
}

/// “全部转出”计算结果。
class TransferMaximumAmountResult {
  const TransferMaximumAmountResult._({this.amount, this.failure});

  const TransferMaximumAmountResult.valid(String amount)
    : this._(amount: amount);

  const TransferMaximumAmountResult.invalid(TransferBalanceFailure failure)
    : this._(failure: failure);

  final String? amount;
  final TransferBalanceFailure? failure;

  bool get isValid => amount != null;
}

/// 使用链上最小单位执行转账余额与手续费校验。
///
/// 原生币必须满足 `amount + fee <= balance`；Token 必须同时满足 Token
/// 余额足够以及当前链原生币余额足够支付手续费。
class TransferBalanceValidator {
  const TransferBalanceValidator._();

  static TransferBalanceValidationResult validate({
    required ChainBalance asset,
    required ChainBalance? nativeAsset,
    required String amount,
    required TransferFeeEstimate? feeEstimate,
  }) {
    if (asset.hasError) {
      return const TransferBalanceValidationResult.invalid(
        TransferBalanceFailure.assetBalanceUnavailable,
      );
    }
    if (nativeAsset == null || nativeAsset.hasError) {
      return const TransferBalanceValidationResult.invalid(
        TransferBalanceFailure.nativeBalanceUnavailable,
      );
    }
    if (feeEstimate == null ||
        feeEstimate.rawAmount < BigInt.zero ||
        feeEstimate.symbol.toUpperCase() != nativeAsset.symbol.toUpperCase()) {
      return const TransferBalanceValidationResult.invalid(
        TransferBalanceFailure.feeUnavailable,
      );
    }

    final transferRaw = WalletTransferService.amountToRawUnits(
      amount,
      asset.decimals,
    );
    final assetBalanceRaw = balanceToRawUnits(asset.amount, asset.decimals);
    if (transferRaw > assetBalanceRaw) {
      return const TransferBalanceValidationResult.invalid(
        TransferBalanceFailure.insufficientAssetBalance,
      );
    }

    final nativeBalanceRaw = balanceToRawUnits(
      nativeAsset.amount,
      nativeAsset.decimals,
    );
    final requiredNativeRaw = asset.isNative
        ? transferRaw + feeEstimate.rawAmount
        : feeEstimate.rawAmount;
    if (requiredNativeRaw > nativeBalanceRaw) {
      return const TransferBalanceValidationResult.invalid(
        TransferBalanceFailure.insufficientNativeFeeBalance,
      );
    }
    return const TransferBalanceValidationResult.valid();
  }

  /// 返回安全的全部转出金额。
  ///
  /// Token 可直接填写完整余额；原生币需要先扣除最新预估手续费。
  static TransferMaximumAmountResult maximumTransferAmount({
    required ChainBalance asset,
    required TransferFeeEstimate? feeEstimate,
  }) {
    if (asset.hasError) {
      return const TransferMaximumAmountResult.invalid(
        TransferBalanceFailure.assetBalanceUnavailable,
      );
    }
    final balanceRaw = balanceToRawUnits(asset.amount, asset.decimals);
    if (!asset.isNative) {
      if (balanceRaw <= BigInt.zero) {
        return const TransferMaximumAmountResult.invalid(
          TransferBalanceFailure.insufficientAssetBalance,
        );
      }
      return TransferMaximumAmountResult.valid(
        _rawUnitsToInputAmount(balanceRaw, asset.decimals),
      );
    }
    if (feeEstimate == null ||
        feeEstimate.rawAmount < BigInt.zero ||
        feeEstimate.symbol.toUpperCase() != asset.symbol.toUpperCase()) {
      return const TransferMaximumAmountResult.invalid(
        TransferBalanceFailure.feeUnavailable,
      );
    }
    final maximumRaw = balanceRaw - feeEstimate.rawAmount;
    if (maximumRaw <= BigInt.zero) {
      return const TransferMaximumAmountResult.invalid(
        TransferBalanceFailure.insufficientNativeFeeBalance,
      );
    }
    return TransferMaximumAmountResult.valid(
      _rawUnitsToInputAmount(maximumRaw, asset.decimals),
    );
  }

  /// 将非负余额字符串精确转换为链上最小单位。
  static BigInt balanceToRawUnits(String amount, int decimals) {
    final normalized = amount.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(normalized);
    if (match == null || decimals < 0) {
      throw const FormatException('Invalid asset balance');
    }
    final whole = match.group(1)!;
    final fraction = match.group(2) ?? '';
    if (fraction.length > decimals) {
      throw const FormatException('Asset balance exceeds decimals');
    }
    final raw = '$whole${fraction.padRight(decimals, '0')}';
    return BigInt.parse(raw);
  }

  static String _rawUnitsToInputAmount(BigInt value, int decimals) {
    if (decimals == 0) return value.toString();
    final base = BigInt.from(10).pow(decimals);
    final whole = value ~/ base;
    final fraction = value.remainder(base).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? whole.toString() : '$whole.$trimmed';
  }
}
