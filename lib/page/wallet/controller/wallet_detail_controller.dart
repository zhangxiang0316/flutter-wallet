import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/wallet_secret_store.dart';

class WalletDetailController extends BaseController {
  WalletDetailController({WalletRepository? repository})
    : _repository = repository ?? WalletRepository();

  final WalletRepository _repository;

  WalletAccount? wallet;
  String privateKeyText = '';
  String mnemonicText = '';
  bool hasMnemonic = false;
  bool isUnlockingPrivateKey = false;
  bool isUnlockingMnemonic = false;
  bool isRenamingWallet = false;

  @override
  void onInit() {
    super.onInit();
    loadWallet();
  }

  Future<void> loadWallet() async {
    final walletId = _walletIdFromArguments();
    final wallets = await _repository.loadWallets();
    wallet = wallets.firstWhere(
      (item) => item.id == walletId,
      orElse: () => wallets.isEmpty
          ? WalletAccount(
              id: '',
              name: '',
              bscAddress: '',
              tronAddress: '',
              solanaAddress: '',
              createdAt: DateTime.now(),
            )
          : wallets.first,
    );
    if (wallet?.id.isEmpty ?? true) {
      wallet = null;
    }
    hasMnemonic = wallet == null
        ? false
        : await _repository.hasWalletMnemonic(wallet!.id);
    update();
  }

  Future<bool> unlockPrivateKey(String password) async {
    final currentWallet = wallet;
    if (currentWallet == null || isUnlockingPrivateKey) return false;
    try {
      isUnlockingPrivateKey = true;
      update();
      privateKeyText = await _repository.readWalletPrivateKey(
        walletId: currentWallet.id,
        password: password,
      );
      update();
      return true;
    } on WalletSecretMissingException {
      Toast.show(S.current.walletSecretMissing);
      return false;
    } on WalletSecretInvalidPasswordException {
      Toast.show(S.current.invalidWalletPassword);
      return false;
    } finally {
      isUnlockingPrivateKey = false;
      update();
    }
  }

  Future<bool> unlockMnemonic(String password) async {
    final currentWallet = wallet;
    if (currentWallet == null || isUnlockingMnemonic) return false;
    try {
      isUnlockingMnemonic = true;
      update();
      mnemonicText = await _repository.readWalletMnemonic(
        walletId: currentWallet.id,
        password: password,
      );
      update();
      return true;
    } on WalletSecretMissingException {
      Toast.show(S.current.walletSecretMissing);
      return false;
    } on WalletSecretInvalidPasswordException {
      Toast.show(S.current.invalidWalletPassword);
      return false;
    } finally {
      isUnlockingMnemonic = false;
      update();
    }
  }

  Future<bool> renameWallet(String name) async {
    final currentWallet = wallet;
    final trimmedName = name.trim();
    if (currentWallet == null || isRenamingWallet) return false;
    if (trimmedName.isEmpty) {
      Toast.show(S.current.walletNameRequired);
      return false;
    }

    try {
      isRenamingWallet = true;
      update();
      final nextWallet = await _repository.renameWallet(
        walletId: currentWallet.id,
        name: trimmedName,
      );
      if (nextWallet == null) {
        Toast.show(S.current.balanceLoadFailed);
        return false;
      }
      wallet = nextWallet;
      Toast.show(S.current.walletNameUpdated);
      update();
      return true;
    } finally {
      isRenamingWallet = false;
      update();
    }
  }

  String _walletIdFromArguments() {
    final args = Get.arguments;
    if (args is String) {
      return args;
    }
    return '';
  }
}
