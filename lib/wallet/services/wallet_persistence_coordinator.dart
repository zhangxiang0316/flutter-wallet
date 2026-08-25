import '../../utils/storage.dart';
import '../models/wallet_account.dart';
import 'crypto/wallet_secret_store.dart';
import 'wallet_local_data_cleanup_service.dart';
import 'wallet_persistence_transaction.dart';

typedef WalletStateWriter =
    Future<void> Function(List<WalletAccount> wallets, String? currentWalletId);

/// 协调 Secure Storage 与钱包元数据存储的可恢复事务。
class WalletPersistenceCoordinator {
  WalletPersistenceCoordinator({
    required KeyValueStorage storage,
    required WalletSecretStore secretStore,
    required WalletLocalDataCleanupService cleanupService,
    required WalletStateWriter writeWalletState,
  }) : _storage = storage,
       _secretStore = secretStore,
       _cleanupService = cleanupService,
       _writeWalletState = writeWalletState;

  final KeyValueStorage _storage;
  final WalletSecretStore _secretStore;
  final WalletLocalDataCleanupService _cleanupService;
  final WalletStateWriter _writeWalletState;

  Future<void> upsert({
    required WalletAccount wallet,
    required String password,
    required String privateKeyHex,
    required String? mnemonic,
    required List<WalletAccount> previousWallets,
    required String? previousCurrentWalletId,
  }) async {
    var transaction = _newTransaction(
      operation: WalletPersistenceOperation.upsert,
      walletId: wallet.id,
      previousWallets: previousWallets,
      previousCurrentWalletId: previousCurrentWalletId,
    );
    await _writeTransaction(transaction);
    try {
      await _secretStore.removePrivateKey(transaction.stagingWalletId);
      await _secretStore.removePrivateKey(transaction.backupWalletId);
      await _secretStore.savePrivateKey(
        walletId: transaction.stagingWalletId,
        password: password,
        privateKeyHex: privateKeyHex,
      );
      final normalizedMnemonic = mnemonic?.trim() ?? '';
      if (normalizedMnemonic.isNotEmpty) {
        await _secretStore.saveMnemonic(
          walletId: transaction.stagingWalletId,
          password: password,
          mnemonic: normalizedMnemonic,
        );
      }

      final hadExistingSecrets = await _secretStore.hasAnySecrets(wallet.id);
      if (hadExistingSecrets) {
        await _secretStore.copySecrets(
          fromWalletId: wallet.id,
          toWalletId: transaction.backupWalletId,
        );
        if (normalizedMnemonic.isEmpty &&
            await _secretStore.hasMnemonic(wallet.id)) {
          final existingMnemonic = await _secretStore.readMnemonic(
            walletId: wallet.id,
            password: password,
          );
          await _secretStore.saveMnemonic(
            walletId: transaction.stagingWalletId,
            password: password,
            mnemonic: existingMnemonic,
          );
        }
      }
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.secretsPrepared,
        hadExistingSecrets: hadExistingSecrets,
      );

      final nextWallets = [...previousWallets];
      _upsertWallet(nextWallets, wallet);
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.metadataCommitPending,
        metadataMayHaveChanged: true,
      );
      await _writeWalletState(nextWallets, wallet.id);
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.metadataCommitted,
      );

      await _secretStore.copySecrets(
        fromWalletId: transaction.stagingWalletId,
        toWalletId: wallet.id,
      );
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.cleanupPending,
      );
    } catch (error, stackTrace) {
      await _rollbackFailedTransaction(transaction);
      Error.throwWithStackTrace(error, stackTrace);
    }
    await _tryFinishCommittedCleanup(transaction);
  }

  Future<void> remove({
    required String walletId,
    required List<WalletAccount> previousWallets,
    required String? previousCurrentWalletId,
  }) async {
    var transaction = _newTransaction(
      operation: WalletPersistenceOperation.remove,
      walletId: walletId,
      previousWallets: previousWallets,
      previousCurrentWalletId: previousCurrentWalletId,
    );
    await _writeTransaction(transaction);
    try {
      await _secretStore.removePrivateKey(transaction.stagingWalletId);
      await _secretStore.removePrivateKey(transaction.backupWalletId);
      final hadExistingSecrets = await _secretStore.hasAnySecrets(walletId);
      if (hadExistingSecrets) {
        await _secretStore.copySecrets(
          fromWalletId: walletId,
          toWalletId: transaction.backupWalletId,
        );
      }
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.secretsPrepared,
        hadExistingSecrets: hadExistingSecrets,
      );

      final nextWallets = [...previousWallets]
        ..removeWhere((wallet) => wallet.id == walletId);
      final nextCurrentWalletId = previousCurrentWalletId == walletId
          ? (nextWallets.isEmpty ? null : nextWallets.first.id)
          : previousCurrentWalletId;
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.metadataCommitPending,
        metadataMayHaveChanged: true,
      );
      await _writeWalletState(nextWallets, nextCurrentWalletId);
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.metadataCommitted,
      );

      await _secretStore.removePrivateKey(walletId);
      transaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.cleanupPending,
      );
    } catch (error, stackTrace) {
      await _rollbackFailedTransaction(transaction);
      Error.throwWithStackTrace(error, stackTrace);
    }
    await _tryFinishCommittedCleanup(transaction);
  }

  /// 在读取钱包元数据前恢复上一次被中断的事务。
  Future<void> recoverPendingTransaction() async {
    final transaction = await _readTransaction();
    if (transaction == null) return;
    switch (transaction.phase) {
      case WalletPersistencePhase.pending:
      case WalletPersistencePhase.secretsPrepared:
        await _tryDiscardUncommittedTransaction(transaction);
        return;
      case WalletPersistencePhase.metadataCommitPending:
      case WalletPersistencePhase.rollbackPending:
        await _performRollback(transaction);
        return;
      case WalletPersistencePhase.metadataCommitted:
        if (transaction.operation == WalletPersistenceOperation.upsert) {
          await _secretStore.copySecrets(
            fromWalletId: transaction.stagingWalletId,
            toWalletId: transaction.walletId,
          );
        } else {
          try {
            await _secretStore.removePrivateKey(transaction.walletId);
          } catch (_) {
            return;
          }
        }
        final cleanupTransaction = await _advanceTransaction(
          transaction,
          WalletPersistencePhase.cleanupPending,
        );
        await _tryFinishCommittedCleanup(cleanupTransaction);
        return;
      case WalletPersistencePhase.cleanupPending:
        await _tryFinishCommittedCleanup(transaction);
        return;
    }
  }

  Future<void> ensureNoPendingTransaction() async {
    if (await _readTransaction() != null) {
      throw StateError('Wallet persistence recovery is still pending');
    }
  }

  WalletPersistenceTransaction _newTransaction({
    required WalletPersistenceOperation operation,
    required String walletId,
    required List<WalletAccount> previousWallets,
    required String? previousCurrentWalletId,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${walletId.hashCode}';
    return WalletPersistenceTransaction(
      id: id,
      operation: operation,
      phase: WalletPersistencePhase.pending,
      walletId: walletId,
      stagingWalletId: '__wallet_tx_staging_$id',
      backupWalletId: '__wallet_tx_backup_$id',
      previousWallets: List<WalletAccount>.unmodifiable(previousWallets),
      previousCurrentWalletId: previousCurrentWalletId,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<WalletPersistenceTransaction> _advanceTransaction(
    WalletPersistenceTransaction transaction,
    WalletPersistencePhase phase, {
    bool? hadExistingSecrets,
    bool? metadataMayHaveChanged,
  }) async {
    final next = transaction.copyWith(
      phase: phase,
      hadExistingSecrets: hadExistingSecrets,
      metadataMayHaveChanged: metadataMayHaveChanged,
    );
    await _writeTransaction(next);
    return next;
  }

  Future<void> _writeTransaction(WalletPersistenceTransaction transaction) {
    return _storage.setJsonMap(
      WalletPersistenceTransaction.journalStorageKey,
      transaction.toJson(),
    );
  }

  Future<WalletPersistenceTransaction?> _readTransaction() async {
    final json = await _storage.getJsonMap(
      WalletPersistenceTransaction.journalStorageKey,
    );
    if (json == null) return null;
    return WalletPersistenceTransaction.fromJson(json);
  }

  Future<void> _rollbackFailedTransaction(
    WalletPersistenceTransaction transaction,
  ) async {
    WalletPersistenceTransaction rollbackTransaction;
    try {
      rollbackTransaction = await _advanceTransaction(
        transaction,
        WalletPersistencePhase.rollbackPending,
      );
    } catch (_) {
      return;
    }
    try {
      await _performRollback(rollbackTransaction);
    } catch (_) {
      // rollbackPending 会在下次启动或读取钱包时继续执行。
    }
  }

  Future<void> _performRollback(
    WalletPersistenceTransaction transaction,
  ) async {
    if (transaction.metadataMayHaveChanged) {
      if (transaction.hadExistingSecrets) {
        await _secretStore.copySecrets(
          fromWalletId: transaction.backupWalletId,
          toWalletId: transaction.walletId,
        );
      } else {
        await _secretStore.removePrivateKey(transaction.walletId);
      }
      await _writeWalletState(
        transaction.previousWallets,
        transaction.previousCurrentWalletId,
      );
    }
    await _secretStore.removePrivateKey(transaction.stagingWalletId);
    await _secretStore.removePrivateKey(transaction.backupWalletId);
    await _storage.remove(WalletPersistenceTransaction.journalStorageKey);
  }

  Future<void> _tryDiscardUncommittedTransaction(
    WalletPersistenceTransaction transaction,
  ) async {
    try {
      await _secretStore.removePrivateKey(transaction.stagingWalletId);
      await _secretStore.removePrivateKey(transaction.backupWalletId);
      await _storage.remove(WalletPersistenceTransaction.journalStorageKey);
    } catch (_) {
      // 正式钱包尚未变化，残留 staging 数据由下一次读取继续清理。
    }
  }

  Future<void> _tryFinishCommittedCleanup(
    WalletPersistenceTransaction transaction,
  ) async {
    try {
      if (transaction.operation == WalletPersistenceOperation.remove) {
        await _cleanupService.clearWallet(transaction.walletId);
      }
      await _secretStore.removePrivateKey(transaction.stagingWalletId);
      await _secretStore.removePrivateKey(transaction.backupWalletId);
      await _storage.remove(WalletPersistenceTransaction.journalStorageKey);
    } catch (_) {
      // 正式状态已经提交，保留 cleanupPending journal 并在后续读取时重试。
    }
  }

  void _upsertWallet(List<WalletAccount> wallets, WalletAccount wallet) {
    final index = wallets.indexWhere((item) => item.id == wallet.id);
    if (index < 0) {
      wallets.add(wallet);
    } else {
      wallets[index] = wallet;
    }
  }
}
