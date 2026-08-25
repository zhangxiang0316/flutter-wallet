part of 'home_controller.dart';

/// Upgrades legacy wallet metadata with addresses added by newer chain support.
class WalletAddressUpgradeService {
  WalletAddressUpgradeService({
    required WalletRepository repository,
    required WalletCryptoService cryptoService,
  }) : _repository = repository,
       _cryptoService = cryptoService;

  final WalletRepository _repository;
  final WalletCryptoService _cryptoService;

  Future<WalletSnapshot> upgradeMissingAddresses({
    required String password,
    Set<String>? walletIds,
    String? selectedWalletId,
  }) async {
    final currentWalletId =
        selectedWalletId ?? await _repository.loadCurrentWalletId();
    final nextWallets = <WalletAccount>[];
    for (final wallet in await _repository.loadWallets()) {
      final shouldUpgrade =
          HomeControllerUtils.needsChainAddressUpgrade(wallet) &&
          (walletIds?.contains(wallet.id) ?? wallet.id == currentWalletId);
      nextWallets.add(
        shouldUpgrade
            ? await _upgradeWallet(wallet: wallet, password: password)
            : wallet,
      );
    }
    await _repository.saveWallets(
      nextWallets,
      currentWalletId: currentWalletId,
    );
    final snapshot = await _repository.loadWalletSnapshot();
    return WalletSnapshot(
      wallets: snapshot.wallets,
      currentWallet: snapshot.currentWallet,
    );
  }

  Future<WalletAccount> _upgradeWallet({
    required WalletAccount wallet,
    required String password,
  }) async {
    var result = wallet;
    if (wallet.solanaAddress.trim().isEmpty) {
      final privateKey = await _evmPrivateKey(wallet, password);
      result = result.copyWith(
        solanaAddress: _cryptoService
            .importPrivateKey(privateKey)
            .solanaAddress,
      );
    }
    if (wallet.suiAddress.trim().isEmpty) {
      final privateKey = wallet.needsSecretMigration
          ? _cryptoService.suiPrivateKeyFromPrivateKey(wallet.privateKeyHex)
          : await _repository.readWalletSuiPrivateKey(
              walletId: wallet.id,
              password: password,
            );
      result = result.copyWith(
        suiAddress: _cryptoService.suiAddressFromPrivateKey(privateKey),
      );
    }
    if (wallet.aptosAddress.trim().isEmpty) {
      final privateKey = wallet.needsSecretMigration
          ? _cryptoService.aptosPrivateKeyFromPrivateKey(wallet.privateKeyHex)
          : await _repository.readWalletAptosPrivateKey(
              walletId: wallet.id,
              password: password,
            );
      result = result.copyWith(
        aptosAddress: _cryptoService.aptosAddressFromPrivateKey(privateKey),
      );
    }
    if (wallet.bitcoinAddress.trim().isEmpty) {
      final privateKey = wallet.needsSecretMigration
          ? _cryptoService.bitcoinPrivateKeyFromPrivateKey(wallet.privateKeyHex)
          : await _repository.readWalletBitcoinPrivateKey(
              walletId: wallet.id,
              password: password,
            );
      result = result.copyWith(
        bitcoinAddress: _cryptoService.bitcoinAddressFromPrivateKey(privateKey),
      );
    }
    return result;
  }

  Future<String> _evmPrivateKey(WalletAccount wallet, String password) async {
    return wallet.needsSecretMigration
        ? wallet.privateKeyHex
        : _repository.readWalletPrivateKey(
            walletId: wallet.id,
            password: password,
          );
  }
}
