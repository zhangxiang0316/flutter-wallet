import 'package:flutter/material.dart';

/// 交易风险等级
enum RiskLevel {
  low,
  medium,
  high,
}

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

  /// 是否需要显示警告
  bool get shouldWarn => level != RiskLevel.low;
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
  }) {
    try {
      final amountValue = double.parse(amount);
      final balanceValue = double.parse(balance);

      if (amountValue <= 0 || balanceValue <= 0) {
        return null;
      }

      final percentage = (amountValue / balanceValue) * 100;

      if (percentage >= 90) {
        return TransactionRisk(
          level: RiskLevel.high,
          message: 'You are transferring ${percentage.toStringAsFixed(0)}% of your balance',
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
        );
      } else if (percentage >= 50) {
        return TransactionRisk(
          level: RiskLevel.medium,
          message: 'You are transferring ${percentage.toStringAsFixed(0)}% of your balance',
          icon: Icons.info_outline_rounded,
          color: Colors.orange,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检测新地址
  ///
  /// 如果是首次向该地址转账，返回中风险提示
  static TransactionRisk? checkNewRecipient({
    required String address,
    required List<String> historyAddresses,
  }) {
    if (historyAddresses.isEmpty) {
      return null; // 没有历史记录，无法判断
    }

    final normalizedAddress = address.toLowerCase();
    final isNewAddress = !historyAddresses
        .any((addr) => addr.toLowerCase() == normalizedAddress);

    if (isNewAddress) {
      return TransactionRisk(
        level: RiskLevel.medium,
        message: 'This is the first time you are sending to this address',
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
  }) {
    try {
      final feeValue = double.parse(fee);
      final amountValue = double.parse(amount);

      if (feeValue <= 0 || amountValue <= 0) {
        return null;
      }

      final feePercentage = (feeValue / amountValue) * 100;

      if (feePercentage >= 20) {
        return TransactionRisk(
          level: RiskLevel.high,
          message: 'Fee is ${feePercentage.toStringAsFixed(0)}% of transfer amount (unusually high)',
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
        );
      } else if (feePercentage >= 10) {
        return TransactionRisk(
          level: RiskLevel.medium,
          message: 'Fee is ${feePercentage.toStringAsFixed(0)}% of transfer amount',
          icon: Icons.info_outline_rounded,
          color: Colors.orange,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 综合检测所有风险
  ///
  /// 返回所有检测到的风险列表，按严重程度排序
  static List<TransactionRisk> checkAllRisks({
    required String amount,
    required String balance,
    required String recipientAddress,
    required List<String> historyAddresses,
    String? fee,
  }) {
    final risks = <TransactionRisk>[];

    // 检测大额转账
    final largeAmountRisk = checkLargeAmount(
      amount: amount,
      balance: balance,
    );
    if (largeAmountRisk != null) {
      risks.add(largeAmountRisk);
    }

    // 检测新地址
    final newRecipientRisk = checkNewRecipient(
      address: recipientAddress,
      historyAddresses: historyAddresses,
    );
    if (newRecipientRisk != null) {
      risks.add(newRecipientRisk);
    }

    // 检测高手续费
    if (fee != null) {
      final highFeeRisk = checkHighFee(
        fee: fee,
        amount: amount,
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
}
