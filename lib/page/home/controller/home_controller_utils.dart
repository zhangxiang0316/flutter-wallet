import 'package:decimal/decimal.dart';

import '../../../wallet/models/wallet_account.dart';

/// 首页控制器使用的纯工具方法。
///
/// 这里不持有页面状态，便于后续继续拆分余额刷新、估值和钱包迁移流程。
class HomeControllerUtils {
  const HomeControllerUtils._();

  static bool isZeroAmount(String value) {
    return amountDecimal(value) == Decimal.zero;
  }

  static Decimal amountDecimal(String value) {
    return Decimal.tryParse(value.trim()) ?? Decimal.zero;
  }

  /// 当前项目使用 EVM 地址小写形式作为钱包 ID。
  static String createWalletId(String evmAddress) {
    return evmAddress.toLowerCase();
  }

  /// 判断当前钱包是否需要补全 Solana 地址。
  static bool needsSolanaAddressUpgrade(WalletAccount? wallet) {
    return wallet != null &&
        wallet.solanaAddress.trim().isEmpty &&
        !wallet.needsSecretMigration;
  }
}
