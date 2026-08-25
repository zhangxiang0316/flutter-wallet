part of 'home_controller.dart';

/// Coordinates plaintext-secret migration and the related address upgrade.
class WalletMigrationService {
  WalletMigrationService({
    required WalletRepository repository,
    required WalletAddressUpgradeService addressUpgradeService,
  }) : _repository = repository,
       _addressUpgradeService = addressUpgradeService;

  final WalletRepository _repository;
  final WalletAddressUpgradeService _addressUpgradeService;

  Future<WalletSnapshot> migrateLegacySecrets({
    required String password,
    required List<WalletAccount> wallets,
    String? selectedWalletId,
  }) async {
    final legacyWalletIds = wallets
        .where((wallet) => wallet.needsSecretMigration)
        .map((wallet) => wallet.id)
        .toSet();
    await _repository.migrateLegacyPlainSecrets(password);
    return _addressUpgradeService.upgradeMissingAddresses(
      password: password,
      walletIds: legacyWalletIds,
      selectedWalletId: selectedWalletId,
    );
  }
}
