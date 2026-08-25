import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/utils/password_cache_service.dart';
import 'package:omnicast/utils/storage.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/services/config/wallet_backup_status_service.dart';
import 'package:omnicast/wallet/services/crypto/wallet_secret_store.dart';
import 'package:omnicast/wallet/services/wallet_local_data_cleanup_service.dart';
import 'package:omnicast/wallet/services/wallet_persistence_transaction.dart';
import 'package:omnicast/wallet/services/wallet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldPrivateKey =
      '0000000000000000000000000000000000000000000000000000000000000001';
  const newPrivateKey =
      '0000000000000000000000000000000000000000000000000000000000000002';
  const mnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PasswordCacheService.clearCache();
  });

  test('rolls back when the staged private key write fails', () async {
    final storage = _MemoryStorage();
    final secrets = _FailingWalletSecretStore()
      ..failStagedPrivateKeyWrite = true;
    final repository = _repository(storage, secrets);

    await expectLater(
      repository.saveWalletWithSecret(
        wallet: _wallet(),
        password: 'new-password',
        privateKeyHex: newPrivateKey,
        mnemonic: mnemonic,
      ),
      throwsStateError,
    );

    expect(await repository.loadWallets(), isEmpty);
    expect(
      await storage.getJsonMap(WalletPersistenceTransaction.journalStorageKey),
      isNull,
    );
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test('removes a partial staging key when mnemonic write fails', () async {
    final storage = _MemoryStorage();
    final secrets = _FailingWalletSecretStore()..failStagedMnemonicWrite = true;
    final repository = _repository(storage, secrets);

    await expectLater(
      repository.saveWalletWithSecret(
        wallet: _wallet(),
        password: 'new-password',
        privateKeyHex: newPrivateKey,
        mnemonic: mnemonic,
      ),
      throwsStateError,
    );

    expect(await repository.loadWallets(), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test('restores the old secret when metadata commit fails', () async {
    final storage = _MemoryStorage();
    final secrets = _FailingWalletSecretStore();
    final repository = _repository(storage, secrets);
    final originalWallet = _wallet(name: 'Original');
    await repository.saveWalletSecret(
      walletId: originalWallet.id,
      password: 'old-password',
      privateKeyHex: oldPrivateKey,
      mnemonic: mnemonic,
    );
    await repository.saveWallet(originalWallet);
    storage.failNextWalletListWrite = true;

    await expectLater(
      repository.saveWalletWithSecret(
        wallet: _wallet(name: 'Updated'),
        password: 'new-password',
        privateKeyHex: newPrivateKey,
        mnemonic: mnemonic,
      ),
      throwsStateError,
    );

    expect((await repository.loadWallets()).single.name, 'Original');
    expect(
      await repository.readWalletPrivateKey(
        walletId: originalWallet.id,
        password: 'old-password',
      ),
      oldPrivateKey,
    );
    await expectLater(
      repository.readWalletPrivateKey(
        walletId: originalWallet.id,
        password: 'new-password',
      ),
      throwsA(isA<WalletSecretInvalidPasswordException>()),
    );
  });

  test('private-key reimport preserves an existing mnemonic', () async {
    final storage = _MemoryStorage();
    final secrets = _FailingWalletSecretStore();
    final repository = _repository(storage, secrets);
    final wallet = _wallet();
    await repository.saveWalletWithSecret(
      wallet: wallet,
      password: 'old-password',
      privateKeyHex: oldPrivateKey,
      mnemonic: mnemonic,
    );

    await repository.saveWalletWithSecret(
      wallet: wallet,
      password: 'old-password',
      privateKeyHex: oldPrivateKey,
    );

    expect(
      await repository.readWalletMnemonic(
        walletId: wallet.id,
        password: 'old-password',
      ),
      mnemonic,
    );
  });

  test('restores metadata and secret when committed deletion fails', () async {
    final storage = _MemoryStorage();
    final secrets = _FailingWalletSecretStore();
    final repository = _repository(storage, secrets);
    final wallet = _wallet();
    await repository.saveWalletWithSecret(
      wallet: wallet,
      password: 'old-password',
      privateKeyHex: oldPrivateKey,
      mnemonic: mnemonic,
    );
    secrets
      ..deleteFailureWalletId = wallet.id
      ..remainingTargetDeleteFailures = 1;

    await expectLater(repository.removeWallet(wallet.id), throwsStateError);

    expect((await repository.loadWallets()).single.id, wallet.id);
    expect(
      await repository.readWalletPrivateKey(
        walletId: wallet.id,
        password: 'old-password',
      ),
      oldPrivateKey,
    );
    expect(
      await storage.getJsonMap(WalletPersistenceTransaction.journalStorageKey),
      isNull,
    );
  });

  test('finishes a metadata-committed upsert after app interruption', () async {
    final storage = _MemoryStorage();
    final secrets = _FailingWalletSecretStore();
    final wallet = _wallet();
    const transactionId = 'interrupted-upsert';
    const stagingWalletId = '__wallet_tx_staging_$transactionId';
    const backupWalletId = '__wallet_tx_backup_$transactionId';
    await secrets.savePrivateKey(
      walletId: stagingWalletId,
      password: 'new-password',
      privateKeyHex: newPrivateKey,
    );
    await secrets.saveMnemonic(
      walletId: stagingWalletId,
      password: 'new-password',
      mnemonic: mnemonic,
    );
    await storage.setJsonList('crypto_wallet_accounts', [wallet.toJson()]);
    await storage.setString('crypto_current_wallet_id', wallet.id);
    await storage.setJsonMap(
      WalletPersistenceTransaction.journalStorageKey,
      WalletPersistenceTransaction(
        id: transactionId,
        operation: WalletPersistenceOperation.upsert,
        phase: WalletPersistencePhase.metadataCommitted,
        walletId: wallet.id,
        stagingWalletId: stagingWalletId,
        backupWalletId: backupWalletId,
        previousWallets: const [],
        previousCurrentWalletId: null,
        hadExistingSecrets: false,
        metadataMayHaveChanged: true,
        createdAt: DateTime.utc(2026, 8, 25),
      ).toJson(),
    );

    final repository = _repository(storage, secrets);
    expect((await repository.loadWallets()).single.id, wallet.id);
    expect(
      await repository.readWalletPrivateKey(
        walletId: wallet.id,
        password: 'new-password',
      ),
      newPrivateKey,
    );
    expect(await secrets.hasAnySecrets(stagingWalletId), isFalse);
    expect(
      await storage.getJsonMap(WalletPersistenceTransaction.journalStorageKey),
      isNull,
    );
  });

  test(
    'deletion clears wallet-scoped balances, history and backup state',
    () async {
      final wallet = _wallet();
      SharedPreferences.setMockInitialValues({
        'cached_balances_v3_${wallet.id}': '{}',
        'cached_balances_v2_${wallet.id}': '{}',
        'tx_history_v1_${wallet.id}_evm-1_native_ETH': '{}',
        'tx_local_v1_${wallet.id}_evm-1_native_ETH': '{}',
        'tx_history_v1_other-wallet_evm-1_native_ETH': '{}',
      });
      await WalletBackupStatusService().markMnemonicBackedUp(wallet.id);
      await PasswordCacheService.cachePassword(
        walletId: wallet.id,
        password: 'old-password',
      );
      final storage = _MemoryStorage();
      final secrets = _FailingWalletSecretStore();
      final repository = WalletRepository(
        storage: storage,
        secretStore: secrets,
      );
      await repository.saveWalletWithSecret(
        wallet: wallet,
        password: 'old-password',
        privateKeyHex: oldPrivateKey,
        mnemonic: mnemonic,
      );

      await repository.removeWallet(wallet.id);

      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys.where((key) => key.contains(wallet.id)), isEmpty);
      expect(keys, contains('tx_history_v1_other-wallet_evm-1_native_ETH'));
      expect(await PasswordCacheService.hasCachedPassword(wallet.id), isFalse);
      expect(
        await WalletBackupStatusService().isMnemonicBackedUp(wallet.id),
        isFalse,
      );
    },
  );

  test(
    'retries a cleanup-pending deletion on the next repository read',
    () async {
      final storage = _MemoryStorage();
      final secrets = _FailingWalletSecretStore();
      final cleanup = _FailingCleanupService()..remainingFailures = 1;
      final repository = _repository(storage, secrets, cleanupService: cleanup);
      final wallet = _wallet();
      await repository.saveWalletWithSecret(
        wallet: wallet,
        password: 'old-password',
        privateKeyHex: oldPrivateKey,
        mnemonic: mnemonic,
      );

      await repository.removeWallet(wallet.id);

      final pending = await storage.getJsonMap(
        WalletPersistenceTransaction.journalStorageKey,
      );
      expect(pending?['phase'], WalletPersistencePhase.cleanupPending.name);
      expect(cleanup.calls, 1);

      expect(await repository.loadWallets(), isEmpty);
      expect(cleanup.calls, 2);
      expect(
        await storage.getJsonMap(
          WalletPersistenceTransaction.journalStorageKey,
        ),
        isNull,
      );
    },
  );
}

WalletRepository _repository(
  _MemoryStorage storage,
  WalletSecretStore secretStore, {
  WalletLocalDataCleanupService? cleanupService,
}) {
  return WalletRepository(
    storage: storage,
    secretStore: secretStore,
    cleanupService: cleanupService ?? _NoopCleanupService(),
  );
}

WalletAccount _wallet({String name = 'Primary'}) {
  return WalletAccount(
    id: 'wallet-1',
    name: name,
    bscAddress: '0x1111111111111111111111111111111111111111',
    tronAddress: 'tron-address',
    solanaAddress: 'solana-address',
    suiAddress: 'sui-address',
    aptosAddress: 'aptos-address',
    bitcoinAddress: 'bitcoin-address',
    createdAt: DateTime.utc(2026, 8, 25),
  );
}

class _NoopCleanupService extends WalletLocalDataCleanupService {
  @override
  Future<void> clearWallet(String walletId) async {}
}

class _FailingCleanupService extends WalletLocalDataCleanupService {
  int remainingFailures = 0;
  int calls = 0;

  @override
  Future<void> clearWallet(String walletId) async {
    calls++;
    if (remainingFailures > 0) {
      remainingFailures--;
      throw StateError('Injected local data cleanup failure');
    }
  }
}

class _FailingWalletSecretStore extends WalletSecretStore {
  bool failStagedPrivateKeyWrite = false;
  bool failStagedMnemonicWrite = false;
  String? deleteFailureWalletId;
  int remainingTargetDeleteFailures = 0;

  @override
  Future<void> savePrivateKey({
    required String walletId,
    required String password,
    required String privateKeyHex,
  }) {
    if (failStagedPrivateKeyWrite &&
        walletId.startsWith('__wallet_tx_staging_')) {
      throw StateError('Injected private key write failure');
    }
    return super.savePrivateKey(
      walletId: walletId,
      password: password,
      privateKeyHex: privateKeyHex,
    );
  }

  @override
  Future<void> saveMnemonic({
    required String walletId,
    required String password,
    required String mnemonic,
  }) {
    if (failStagedMnemonicWrite &&
        walletId.startsWith('__wallet_tx_staging_')) {
      throw StateError('Injected mnemonic write failure');
    }
    return super.saveMnemonic(
      walletId: walletId,
      password: password,
      mnemonic: mnemonic,
    );
  }

  @override
  Future<void> removePrivateKey(String walletId) {
    if (walletId == deleteFailureWalletId &&
        remainingTargetDeleteFailures > 0) {
      remainingTargetDeleteFailures--;
      throw StateError('Injected wallet deletion failure');
    }
    return super.removePrivateKey(walletId);
  }
}

class _MemoryStorage implements KeyValueStorage {
  final Map<String, Object> _values = {};
  bool failNextWalletListWrite = false;

  @override
  Future<Map<String, dynamic>?> getJsonMap(String key) async {
    final value = _values[key];
    if (value is! String) return null;
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  Future<List<dynamic>?> getJsonList(String key) async {
    final value = _values[key];
    if (value is! String) return null;
    final decoded = jsonDecode(value);
    return decoded is List ? List<dynamic>.from(decoded) : null;
  }

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<Object?> getValue(String key) async => _values[key];

  @override
  Future<bool> remove(String key) async => _values.remove(key) != null;

  @override
  Future<void> setJsonList(String key, List<dynamic> value) async {
    if (key == 'crypto_wallet_accounts' && failNextWalletListWrite) {
      failNextWalletListWrite = false;
      throw StateError('Injected metadata write failure');
    }
    _values[key] = jsonEncode(value);
  }

  @override
  Future<void> setJsonMap(String key, Map<String, dynamic> value) async {
    _values[key] = jsonEncode(value);
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
