import '../../utils/storage.dart';

/// 钱包助记词备份状态服务。
class WalletBackupStatusService {
  WalletBackupStatusService({Storage? storage})
    : _storage = storage ?? Storage();

  final Storage _storage;

  static const String _backedUpWalletsKey = 'wallet_mnemonic_backed_up_ids';

  Future<Set<String>> loadBackedUpWalletIds() async {
    final value = await _storage.getStorage(_backedUpWalletsKey);
    if (value is List) {
      return value.map((item) => item.toString()).toSet();
    }
    return {};
  }

  Future<bool> isMnemonicBackedUp(String walletId) async {
    final id = walletId.trim();
    if (id.isEmpty) return false;
    final ids = await loadBackedUpWalletIds();
    return ids.contains(id);
  }

  Future<void> markMnemonicBackedUp(String walletId) async {
    final id = walletId.trim();
    if (id.isEmpty) return;
    final ids = await loadBackedUpWalletIds();
    ids.add(id);
    await _storage.setStorage(_backedUpWalletsKey, ids.toList(growable: false));
  }

  Future<void> clearMnemonicBackedUp(String walletId) async {
    final id = walletId.trim();
    if (id.isEmpty) return;
    final ids = await loadBackedUpWalletIds();
    ids.remove(id);
    await _storage.setStorage(_backedUpWalletsKey, ids.toList(growable: false));
  }
}
