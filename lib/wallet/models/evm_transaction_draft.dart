/// EVM 交易的手续费类型。
enum EvmFeeType { legacy, eip1559 }

/// 从手续费估算到签名广播期间复用的不可变 EVM 交易草稿。
///
/// 草稿保存会影响签名和最大手续费的全部字段，避免确认页展示一套参数、广播时又
/// 重新请求或回退到另一套参数。Base 等 L2 的 L1 数据费不写入 EVM 交易本身，
/// 但会固定在 [l1DataFee] 中并计入 [maximumFee]。
class EvmTransactionDraft {
  const EvmTransactionDraft({
    required this.chainId,
    required this.from,
    required this.to,
    required this.value,
    required this.data,
    required this.nonce,
    required this.gasLimit,
    required this.feeType,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    required this.l1DataFee,
    this.usedFallbackGasLimit = false,
  }) : assert(
         (feeType == EvmFeeType.legacy &&
                 gasPrice != null &&
                 maxFeePerGas == null &&
                 maxPriorityFeePerGas == null) ||
             (feeType == EvmFeeType.eip1559 &&
                 gasPrice == null &&
                 maxFeePerGas != null &&
                 maxPriorityFeePerGas != null),
       );

  final int chainId;
  final String from;
  final String to;
  final BigInt value;

  /// 带 `0x` 前缀的 calldata；原生币转账为 `0x`。
  final String data;
  final BigInt nonce;
  final BigInt gasLimit;
  final EvmFeeType feeType;
  final BigInt? gasPrice;
  final BigInt? maxFeePerGas;
  final BigInt? maxPriorityFeePerGas;

  /// L2 额外收取的 L1 数据费上限。
  final BigInt l1DataFee;
  final bool usedFallbackGasLimit;

  BigInt get feePerGas => switch (feeType) {
    EvmFeeType.legacy => gasPrice!,
    EvmFeeType.eip1559 => maxFeePerGas!,
  };

  BigInt get executionFee => gasLimit * feePerGas;
  BigInt get maximumFee => executionFee + l1DataFee;
}
