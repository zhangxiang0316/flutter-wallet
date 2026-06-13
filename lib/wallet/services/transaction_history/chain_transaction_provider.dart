import '../../models/chain_balance.dart';
import '../../models/wallet_transaction_record.dart';

/// 链交易记录提供者抽象接口。
///
/// 每条链（EVM、TRON、Solana）都需要实现此接口，负责从链上查询该钱包在该
/// 资产下的交易历史，并统一返回 [WalletTransactionRecord] 列表。
abstract class ChainTransactionProvider {
  /// 加载指定资产的交易记录。
  ///
  /// [walletId] 用于生成页面内稳定的记录 ID。
  /// [asset] 包含链信息、合约地址、钱包地址等。
  ///
  /// 返回该资产的交易记录列表，按时间倒序排列。
  Future<List<WalletTransactionRecord>> loadRecords({
    required String walletId,
    required ChainBalance asset,
  });
}
