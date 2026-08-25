import '../../utils/password_cache_service.dart';
import 'chain_balance_cache.dart';
import 'config/wallet_backup_status_service.dart';
import 'transaction/transaction_history_cache.dart';

/// 删除钱包时需要同步清除的非密钥本地数据。
class WalletLocalDataCleanupService {
  WalletLocalDataCleanupService({
    ChainBalanceCache? balanceCache,
    TransactionHistoryCache? transactionHistoryCache,
    WalletBackupStatusService? backupStatusService,
  }) : _balanceCache = balanceCache ?? ChainBalanceCache(),
       _transactionHistoryCache =
           transactionHistoryCache ?? TransactionHistoryCache(),
       _backupStatusService =
           backupStatusService ?? WalletBackupStatusService();

  final ChainBalanceCache _balanceCache;
  final TransactionHistoryCache _transactionHistoryCache;
  final WalletBackupStatusService _backupStatusService;

  /// 清除余额、交易历史、助记词备份标记和内存密码。
  ///
  /// 除内存密码外的操作均可重复执行，适合 cleanupPending journal 恢复。
  Future<void> clearWallet(String walletId) async {
    await _balanceCache.clearForWalletDeletion(walletId);
    await _transactionHistoryCache.clearWallet(walletId);
    await _backupStatusService.clearMnemonicBackedUp(walletId);
    PasswordCacheService.clearCache(walletId: walletId);
  }
}
