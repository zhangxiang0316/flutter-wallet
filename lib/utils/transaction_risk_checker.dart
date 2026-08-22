import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

/// 交易风险等级
enum RiskLevel { low, medium, high }

/// 交易风险信息
class TransactionRisk {
  final RiskLevel level;
  final String message;
  final IconData icon;
  final Color color;

  TransactionRisk({
    required this.level,
    required this.message,
    required this.icon,
    required this.color,
  });
}

/// 风险检查使用的本地化文案。
class TransactionRiskMessages {
  const TransactionRiskMessages({
    required this.largeAmount,
    required this.newRecipient,
    required this.highFee,
  });

  final String Function(String percentage) largeAmount;
  final String newRecipient;
  final String Function(String percentage) highFee;
}

/// 一次转账风险检查所需的精确数值和地址上下文。
class TransactionRiskContext {
  const TransactionRiskContext({
    required this.amount,
    required this.balance,
    required this.assetSymbol,
    required this.recipientAddress,
    required this.historyAddresses,
    required this.recipientCaseInsensitive,
    this.fee,
    this.feeSymbol,
    this.amountFiatValue,
    this.feeFiatValue,
  });

  final String amount;
  final String balance;
  final String assetSymbol;
  final String recipientAddress;
  final List<String> historyAddresses;
  final bool recipientCaseInsensitive;
  final String? fee;
  final String? feeSymbol;

  /// 转账数量和手续费按同一种法币折算后的值。
  ///
  /// 仅在 Token 与手续费币种不同时使用；缺少任意一侧估值时不会进行跨币种比较。
  final Decimal? amountFiatValue;
  final Decimal? feeFiatValue;
}

/// 交易风险检测器
///
/// 检测交易中的潜在风险，包括：
/// - 大额转账（超过余额的50%）
/// - 新地址（首次转账）
/// - 未知代币合约
/// - 异常高手续费
class TransactionRiskChecker {
  /// 检测大额转账
  ///
  /// 如果转账金额超过余额的50%，返回高风险警告
  static TransactionRisk? checkLargeAmount({
    required String amount,
    required String balance,
    required String Function(String percentage) messageBuilder,
  }) {
    final amountValue = Decimal.tryParse(amount);
    final balanceValue = Decimal.tryParse(balance);
    if (amountValue == null ||
        balanceValue == null ||
        amountValue <= Decimal.zero ||
        balanceValue <= Decimal.zero) {
      return null;
    }

    final percentage = _roundedPercentage(amountValue, balanceValue);
    if (amountValue * Decimal.fromInt(100) >=
        balanceValue * Decimal.fromInt(90)) {
      return TransactionRisk(
        level: RiskLevel.high,
        message: messageBuilder(percentage),
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
      );
    }
    if (amountValue * Decimal.fromInt(100) >=
        balanceValue * Decimal.fromInt(50)) {
      return TransactionRisk(
        level: RiskLevel.medium,
        message: messageBuilder(percentage),
        icon: Icons.info_outline_rounded,
        color: Colors.orange,
      );
    }
    return null;
  }

  /// 检测新地址
  ///
  /// 如果是首次向该地址转账，返回中风险提示
  static TransactionRisk? checkNewRecipient({
    required String address,
    required List<String> historyAddresses,
    required String message,
    required bool caseInsensitive,
  }) {
    final isNewAddress = !historyAddresses.any(
      (item) => _sameAddress(item, address, caseInsensitive),
    );

    if (isNewAddress) {
      return TransactionRisk(
        level: RiskLevel.medium,
        message: message,
        icon: Icons.new_releases_outlined,
        color: Colors.orange,
      );
    }

    return null;
  }

  /// 检测高手续费
  ///
  /// 如果手续费超过转账金额的10%，返回警告
  static TransactionRisk? checkHighFee({
    required String fee,
    required String amount,
    required String feeSymbol,
    required String amountSymbol,
    required String Function(String percentage) messageBuilder,
    Decimal? feeFiatValue,
    Decimal? amountFiatValue,
  }) {
    final sameSymbol =
        feeSymbol.trim().toUpperCase() == amountSymbol.trim().toUpperCase();
    final feeValue = sameSymbol ? Decimal.tryParse(fee) : feeFiatValue;
    final amountValue = sameSymbol ? Decimal.tryParse(amount) : amountFiatValue;
    if (feeValue == null ||
        amountValue == null ||
        feeValue <= Decimal.zero ||
        amountValue <= Decimal.zero) {
      return null;
    }

    final percentage = _roundedPercentage(feeValue, amountValue);
    if (feeValue * Decimal.fromInt(100) >= amountValue * Decimal.fromInt(20)) {
      return TransactionRisk(
        level: RiskLevel.high,
        message: messageBuilder(percentage),
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
      );
    }
    if (feeValue * Decimal.fromInt(100) >= amountValue * Decimal.fromInt(10)) {
      return TransactionRisk(
        level: RiskLevel.medium,
        message: messageBuilder(percentage),
        icon: Icons.info_outline_rounded,
        color: Colors.orange,
      );
    }
    return null;
  }

  /// 检测是否正在转给当前钱包自己的地址。
  static TransactionRisk? checkSelfTransfer({
    required String recipientAddress,
    required String walletAddress,
    required String message,
    required bool caseInsensitive,
  }) {
    if (!_sameAddress(recipientAddress, walletAddress, caseInsensitive)) {
      return null;
    }
    return TransactionRisk(
      level: RiskLevel.medium,
      message: message,
      icon: Icons.swap_horiz_rounded,
      color: Colors.orange,
    );
  }

  /// 检测是否误填了当前 token 合约地址。
  static TransactionRisk? checkTokenContractRecipient({
    required String recipientAddress,
    required String? contractAddress,
    required String message,
    required bool caseInsensitive,
  }) {
    final contract = contractAddress?.trim();
    if (contract == null || contract.isEmpty) return null;
    if (!_sameAddress(recipientAddress, contract, caseInsensitive)) return null;
    return TransactionRisk(
      level: RiskLevel.high,
      message: message,
      icon: Icons.report_problem_outlined,
      color: Colors.red,
    );
  }

  /// 检测常见销毁地址。
  static TransactionRisk? checkBurnAddress({
    required String recipientAddress,
    required String message,
    required bool isEvm,
    required bool isSolana,
    bool isSui = false,
    bool isAptos = false,
  }) {
    final address = recipientAddress.trim();
    final isBurn = isEvm
        ? address.toLowerCase() ==
                  '0x0000000000000000000000000000000000000000' ||
              address.toLowerCase() ==
                  '0x000000000000000000000000000000000000dead'
        : (isSolana && address == '11111111111111111111111111111111') ||
              (isSui &&
                  address.toLowerCase() ==
                      '0x0000000000000000000000000000000000000000000000000000000000000000') ||
              (isAptos &&
                  address.toLowerCase() ==
                      '0x0000000000000000000000000000000000000000000000000000000000000000');
    if (!isBurn) return null;
    return TransactionRisk(
      level: RiskLevel.high,
      message: message,
      icon: Icons.local_fire_department_outlined,
      color: Colors.red,
    );
  }

  /// 检测剪贴板中是否存在另一个同链格式地址。
  static TransactionRisk? checkClipboardMismatch({
    required String recipientAddress,
    required String? clipboardAddress,
    required String message,
    required bool caseInsensitive,
  }) {
    final address = clipboardAddress?.trim();
    if (address == null || address.isEmpty) return null;
    if (_sameAddress(address, recipientAddress, caseInsensitive)) return null;
    return TransactionRisk(
      level: RiskLevel.medium,
      message: message,
      icon: Icons.content_paste_search_rounded,
      color: Colors.orange,
    );
  }

  /// 综合检测所有风险
  ///
  /// 返回所有检测到的风险列表，按严重程度排序
  static List<TransactionRisk> checkAllRisks({
    required TransactionRiskContext context,
    required TransactionRiskMessages messages,
  }) {
    final risks = <TransactionRisk>[];

    // 检测大额转账
    final largeAmountRisk = checkLargeAmount(
      amount: context.amount,
      balance: context.balance,
      messageBuilder: messages.largeAmount,
    );
    if (largeAmountRisk != null) {
      risks.add(largeAmountRisk);
    }

    // 检测新地址
    final newRecipientRisk = checkNewRecipient(
      address: context.recipientAddress,
      historyAddresses: context.historyAddresses,
      message: messages.newRecipient,
      caseInsensitive: context.recipientCaseInsensitive,
    );
    if (newRecipientRisk != null) {
      risks.add(newRecipientRisk);
    }

    // 检测高手续费
    final fee = context.fee;
    final feeSymbol = context.feeSymbol;
    if (fee != null && feeSymbol != null) {
      final highFeeRisk = checkHighFee(
        fee: fee,
        amount: context.amount,
        feeSymbol: feeSymbol,
        amountSymbol: context.assetSymbol,
        feeFiatValue: context.feeFiatValue,
        amountFiatValue: context.amountFiatValue,
        messageBuilder: messages.highFee,
      );
      if (highFeeRisk != null) {
        risks.add(highFeeRisk);
      }
    }

    // 按风险等级排序（高风险在前）
    risks.sort((a, b) {
      final levelOrder = {
        RiskLevel.high: 0,
        RiskLevel.medium: 1,
        RiskLevel.low: 2,
      };
      return (levelOrder[a.level] ?? 2).compareTo(levelOrder[b.level] ?? 2);
    });

    return risks;
  }

  /// 获取最高风险等级
  static RiskLevel getHighestRiskLevel(List<TransactionRisk> risks) {
    if (risks.isEmpty) return RiskLevel.low;

    if (risks.any((r) => r.level == RiskLevel.high)) {
      return RiskLevel.high;
    }
    if (risks.any((r) => r.level == RiskLevel.medium)) {
      return RiskLevel.medium;
    }
    return RiskLevel.low;
  }

  static bool _sameAddress(String left, String right, bool caseInsensitive) {
    final normalizedLeft = left.trim();
    final normalizedRight = right.trim();
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) return false;
    if (caseInsensitive) {
      return normalizedLeft.toLowerCase() == normalizedRight.toLowerCase();
    }
    return normalizedLeft == normalizedRight;
  }

  static String _roundedPercentage(Decimal part, Decimal whole) {
    return ((part * Decimal.fromInt(100)) / whole)
        .toDecimal(scaleOnInfinitePrecision: 8)
        .round()
        .toString();
  }
}
