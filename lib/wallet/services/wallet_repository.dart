import '../../utils/storage.dart';
import '../models/wallet_account.dart';

class WalletRepository {
  WalletRepository({Storage? storage}) : _storage = storage ?? Storage();

  final Storage _storage;
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
    await saveWallets([legacyWallet], currentWalletId: legacyWallet.id);
    await _storage.removeStorage(_walletKey);
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
  }) async {
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
