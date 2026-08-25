part of 'home_controller.dart';

class WalletSnapshot {
  const WalletSnapshot({required this.wallets, required this.currentWallet});

  final List<WalletAccount> wallets;
  final WalletAccount? currentWallet;
}

class CreatedWalletResult {
  const CreatedWalletResult({
    required this.wallet,
    required this.mnemonic,
    required this.wallets,
  });

  final WalletAccount wallet;
  final String mnemonic;
  final List<WalletAccount> wallets;
}

/// Owns wallet creation, import, selection and removal persistence.
class WalletLifecycleService {
  WalletLifecycleService({
    required WalletRepository repository,
    required WalletCryptoService cryptoService,
  }) : _repository = repository,
       _cryptoService = cryptoService;

  final WalletRepository _repository;
  final WalletCryptoService _cryptoService;

  Future<WalletSnapshot> loadSnapshot() async {
    final snapshot = await _repository.loadWalletSnapshot();
    return WalletSnapshot(
      wallets: snapshot.wallets,
      currentWallet: snapshot.currentWallet,
    );
  }

  Future<CreatedWalletResult> create({
    required String password,
    required int walletCount,
  }) async {
    final keyPair = await _cryptoService.generateMnemonicWallet();
    final mnemonic = keyPair.mnemonic;
    if (mnemonic == null || mnemonic.isEmpty) {
      throw StateError('Generated wallet is missing its mnemonic');
    }
    final nextWallet = _walletFromKeyPair(
      keyPair,
      name: 'Wallet ${walletCount + 1}',
    );
    await _saveSecretAndWallet(
      wallet: nextWallet,
      keyPair: keyPair,
      password: password,
    );
    return CreatedWalletResult(
      wallet: nextWallet,
      mnemonic: mnemonic,
      wallets: await _repository.loadWallets(),
    );
  }

  Future<WalletSnapshot> importPrivateKey({
    required String privateKey,
    required String password,
    required List<WalletAccount> currentWallets,
  }) {
    return _importKeyPair(
      keyPair: _cryptoService.importPrivateKey(privateKey),
      password: password,
      currentWallets: currentWallets,
    );
  }

  Future<WalletSnapshot> importMnemonic({
    required String mnemonic,
    required String password,
    required List<WalletAccount> currentWallets,
  }) {
    return _importKeyPair(
      keyPair: _cryptoService.importMnemonic(mnemonic),
      password: password,
      currentWallets: currentWallets,
    );
  }

  Future<void> select(WalletAccount wallet) {
    return _repository.setCurrentWalletId(wallet.id);
  }

  Future<WalletSnapshot> remove(WalletAccount wallet) async {
    await _repository.removeWallet(wallet.id);
    return loadSnapshot();
  }

  Future<WalletSnapshot> reloadKeepingSelection({
    required String? currentWalletId,
    WalletAccount? fallbackWallet,
  }) async {
    final wallets = await _repository.loadWallets();
    WalletAccount? currentWallet;
    if (currentWalletId == null) {
      currentWallet = await _repository.loadCurrentWallet();
    } else {
      for (final item in wallets) {
        if (item.id == currentWalletId) {
          currentWallet = item;
          break;
        }
      }
      currentWallet ??= fallbackWallet;
    }
    return WalletSnapshot(wallets: wallets, currentWallet: currentWallet);
  }

  Future<WalletSnapshot> _importKeyPair({
    required WalletKeyPair keyPair,
    required String password,
    required List<WalletAccount> currentWallets,
  }) async {
    final existingIndex = currentWallets.indexWhere(
      (wallet) =>
          wallet.bscAddress.toLowerCase() == keyPair.bscAddress.toLowerCase(),
    );
    final nextWallet = _walletFromKeyPair(
      keyPair,
      name: existingIndex >= 0
          ? currentWallets[existingIndex].name
          : 'Wallet ${currentWallets.length + 1}',
    );
    await _saveSecretAndWallet(
      wallet: nextWallet,
      keyPair: keyPair,
      password: password,
    );
    return WalletSnapshot(
      wallets: await _repository.loadWallets(),
      currentWallet: nextWallet,
    );
  }

  Future<void> _saveSecretAndWallet({
    required WalletAccount wallet,
    required WalletKeyPair keyPair,
    required String password,
  }) async {
    await _repository.saveWalletWithSecret(
      wallet: wallet,
      password: password,
      privateKeyHex: keyPair.privateKeyHex,
      mnemonic: keyPair.mnemonic,
    );
  }

  WalletAccount _walletFromKeyPair(
    WalletKeyPair keyPair, {
    required String name,
  }) {
    return WalletAccount(
      id: HomeControllerUtils.createWalletId(keyPair.bscAddress),
      name: name,
      bscAddress: keyPair.bscAddress,
      tronAddress: keyPair.tronAddress,
      solanaAddress: keyPair.solanaAddress,
      suiAddress: keyPair.suiAddress,
      aptosAddress: keyPair.aptosAddress,
      bitcoinAddress: keyPair.bitcoinAddress,
      createdAt: DateTime.now(),
    );
  }
}
