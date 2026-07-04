import 'package:decimal/decimal.dart';

import '../../../wallet/models/chain_balance.dart';
import '../../../wallet/models/wallet_account.dart';

/// 首页控制器使用的纯工具方法。
///
/// 这里不持有页面状态，便于后续继续拆分余额刷新、估值和钱包迁移流程。
class HomeControllerUtils {
  const HomeControllerUtils._();

  /// 生成单个资产估值缓存 key。
  ///
  /// 同一条链上可能存在相同 symbol 的自定义资产，因此优先纳入合约地址区分。
  static String assetStableValueKey(ChainBalance balance) {
    return [
      balance.chainId,
      balance.contractAddress ?? 'native',
      balance.symbol,
    ].join(':');
  }

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
