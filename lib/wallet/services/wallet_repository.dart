import '../../utils/storage.dart';
import '../models/wallet_account.dart';

class WalletRepository {
  WalletRepository({Storage? storage}) : _storage = storage ?? Storage();

  final Storage _storage;
  static const String _walletKey = 'crypto_wallet_account';

  Future<WalletAccount?> loadWallet() async {
    final value = await _storage.getStorage(_walletKey);
    if (value is Map) {
      return WalletAccount.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  Future<void> saveWallet(WalletAccount wallet) {
    return _storage.setStorage(_walletKey, wallet.toJson());
  }

  Future<bool> clearWallet() {
    return _storage.removeStorage(_walletKey);
  }
}
