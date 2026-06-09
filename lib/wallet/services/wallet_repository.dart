import '../../utils/storage.dart';
import '../models/wallet_account.dart';
import 'wallet_secret_store.dart';

class WalletRepository {
  WalletRepository({Storage? storage, WalletSecretStore? secretStore})
    : _storage = storage ?? Storage(),
      _secretStore = secretStore ?? WalletSecretStore();

  final Storage _storage;
  final WalletSecretStore _secretStore;
  static const String _walletKey = 'crypto_wallet_account';
  static const String _walletsKey = 'crypto_wallet_accounts';
  static const String _currentWalletIdKey = 'crypto_current_wallet_id';

  Future<List<WalletAccount>> loadWallets() async {
    final value = await _storage.getStorage(_walletsKey);
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => WalletAccount.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    }

    final legacyWallet = await _loadLegacyWallet();
    if (legacyWallet == null) {
      return [];
    }
    return [legacyWallet];
  }

  Future<WalletAccount?> loadCurrentWallet() async {
    final wallets = await loadWallets();
    if (wallets.isEmpty) {
      return null;
    }
    final currentId = await loadCurrentWalletId();
    return wallets.firstWhere(
      (wallet) => wallet.id == currentId,
      orElse: () => wallets.first,
    );
  }

  Future<String?> loadCurrentWalletId() async {
    final value = await _storage.getStorage(_currentWalletIdKey);
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  Future<void> saveWallets(
    List<WalletAccount> wallets, {
    String? currentWalletId,
    bool allowDroppingLegacySecrets = false,
  }) async {
    if (!allowDroppingLegacySecrets &&
        wallets.any((wallet) => wallet.needsSecretMigration)) {
      throw StateError('Legacy wallet secrets must be migrated before saving');
    }
    await _storage.setStorage(
      _walletsKey,
      wallets.map((wallet) => wallet.toJson()).toList(),
    );
    if (currentWalletId != null && currentWalletId.isNotEmpty) {
      await setCurrentWalletId(currentWalletId);
    }
  }

  Future<void> saveWallet(WalletAccount wallet) async {
    final wallets = [...await loadWallets()];
    final index = wallets.indexWhere((item) => item.id == wallet.id);
    if (index >= 0) {
      wallets[index] = wallet;
    } else {
      wallets.add(wallet);
    }
    await saveWallets(wallets, currentWalletId: wallet.id);
  }

  Future<WalletAccount?> renameWallet({
    required String walletId,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return null;
    }

    final wallets = [...await loadWallets()];
    final index = wallets.indexWhere((item) => item.id == walletId);
    if (index < 0) {
      return null;
    }

    final nextWallet = wallets[index].copyWith(name: trimmedName);
    wallets[index] = nextWallet;
    await saveWallets(
      wallets,
      currentWalletId: await loadCurrentWalletId() ?? walletId,
    );
    return nextWallet;
  }

  Future<void> saveWalletSecret({
    required String walletId,
    required String password,
    required String privateKeyHex,
    String? mnemonic,
  }) async {
    await _secretStore.savePrivateKey(
      walletId: walletId,
      password: password,
      privateKeyHex: privateKeyHex,
    );
    if (mnemonic != null && mnemonic.trim().isNotEmpty) {
      await _secretStore.saveMnemonic(
        walletId: walletId,
        password: password,
        mnemonic: mnemonic,
      );
    }
  }

  Future<String> readWalletPrivateKey({
    required String walletId,
    required String password,
  }) {
    return _secretStore.readPrivateKey(walletId: walletId, password: password);
  }

  Future<String> readWalletMnemonic({
    required String walletId,
    required String password,
  }) {
    return _secretStore.readMnemonic(walletId: walletId, password: password);
  }

  Future<bool> hasWalletSecret(String walletId) {
    return _secretStore.hasPrivateKey(walletId);
  }

  Future<bool> hasWalletMnemonic(String walletId) {
    return _secretStore.hasMnemonic(walletId);
  }

  Future<bool> hasLegacyPlainSecrets() async {
    final wallets = await loadWallets();
    return wallets.any((wallet) => wallet.needsSecretMigration);
  }

  Future<void> migrateLegacyPlainSecrets(String password) async {
    final wallets = await loadWallets();
    final legacyWallets = wallets
        .where((wallet) {
          return wallet.needsSecretMigration;
        })
        .toList(growable: false);

    if (legacyWallets.isEmpty) {
      return;
    }

    for (final wallet in legacyWallets) {
      await _secretStore.migratePlainSecret(
        walletId: wallet.id,
        password: password,
        privateKeyHex: wallet.privateKeyHex,
      );
    }

    await saveWallets(
      wallets,
      currentWalletId: await loadCurrentWalletId() ?? wallets.first.id,
      allowDroppingLegacySecrets: true,
    );
    await _storage.removeStorage(_walletKey);
  }

  Future<void> setCurrentWalletId(String walletId) {
    return _storage.setStorage(_currentWalletIdKey, walletId);
  }

  Future<void> removeWallet(String walletId) async {
    final wallets = [...await loadWallets()]
      ..removeWhere((wallet) => wallet.id == walletId);
    final currentId = await loadCurrentWalletId();
    final nextCurrentId = currentId == walletId
        ? (wallets.isEmpty ? null : wallets.first.id)
        : currentId;

    await saveWallets(wallets, currentWalletId: nextCurrentId);
    await _secretStore.removePrivateKey(walletId);
    if (nextCurrentId == null) {
      await _storage.removeStorage(_currentWalletIdKey);
    }
  }

  Future<WalletAccount?> _loadLegacyWallet() async {
    final value = await _storage.getStorage(_walletKey);
    if (value is Map) {
      return WalletAccount.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }
}
