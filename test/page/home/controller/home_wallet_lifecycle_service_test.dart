import 'package:flutter_test/flutter_test.dart';
import 'package:omnicast/page/home/controller/home_controller.dart';
import 'package:omnicast/wallet/models/wallet_account.dart';
import 'package:omnicast/wallet/services/crypto/wallet_crypto_service.dart';
import 'package:omnicast/wallet/services/wallet_repository.dart';

void main() {
  final keyPair = WalletKeyPair(
    privateKeyHex: 'private-key',
    mnemonic: 'test mnemonic',
    derivedAccountsByNamespace: const {
      WalletAddressNamespace.evm: DerivedAccount(
        address: '0x1111111111111111111111111111111111111111',
      ),
      WalletAddressNamespace.tron: DerivedAccount(address: 'tron-address'),
      WalletAddressNamespace.solana: DerivedAccount(address: 'solana-address'),
      WalletAddressNamespace.sui: DerivedAccount(address: 'sui-address'),
      WalletAddressNamespace.aptos: DerivedAccount(address: 'aptos-address'),
      WalletAddressNamespace.bitcoin: DerivedAccount(
        address: 'bitcoin-address',
      ),
    },
  );

  test('creates and selects a wallet through the lifecycle service', () async {
    final repository = _FakeWalletRepository();
    final service = WalletLifecycleService(
      repository: repository,
      cryptoService: _FakeWalletCryptoService(keyPair),
    );

    final result = await service.create(password: 'password', walletCount: 0);

    expect(result.wallet.name, 'Wallet 1');
    expect(result.mnemonic, keyPair.mnemonic);
    expect(result.wallets, hasLength(1));
    expect(repository.currentWalletId, result.wallet.id);
    expect(repository.savedSecretWalletId, result.wallet.id);
    expect(repository.savedPassword, 'password');
  });

  test('keeps the existing name when importing the same EVM address', () async {
    final existing = _wallet(name: 'Primary');
    final repository = _FakeWalletRepository([existing]);
    final service = WalletLifecycleService(
      repository: repository,
      cryptoService: _FakeWalletCryptoService(keyPair),
    );

    final snapshot = await service.importPrivateKey(
      privateKey: 'private-key',
      password: 'password',
      currentWallets: [existing],
    );

    expect(snapshot.currentWallet?.name, 'Primary');
    expect(snapshot.wallets.single.name, 'Primary');
  });

  test('removes wallet through the transactional repository', () async {
    final wallet = _wallet(name: 'Primary');
    final repository = _FakeWalletRepository([wallet]);
    final service = WalletLifecycleService(
      repository: repository,
      cryptoService: _FakeWalletCryptoService(keyPair),
    );

    final snapshot = await service.remove(wallet);

    expect(snapshot.wallets, isEmpty);
    expect(snapshot.currentWallet, isNull);
  });

  test('upgrades every missing chain address outside the controller', () async {
    final wallet = WalletAccount(
      id: keyPair.bscAddress,
      name: 'Legacy',
      bscAddress: keyPair.bscAddress,
      tronAddress: keyPair.tronAddress,
      createdAt: DateTime.utc(2026, 8, 25),
    );
    final repository = _FakeWalletRepository([wallet]);
    final service = WalletAddressUpgradeService(
      repository: repository,
      cryptoService: _FakeWalletCryptoService(keyPair),
    );

    final snapshot = await service.upgradeMissingAddresses(
      password: 'password',
      selectedWalletId: wallet.id,
    );

    final upgraded = snapshot.currentWallet!;
    expect(upgraded.solanaAddress, keyPair.solanaAddress);
    expect(upgraded.suiAddress, keyPair.suiAddress);
    expect(upgraded.aptosAddress, keyPair.aptosAddress);
    expect(upgraded.bitcoinAddress, keyPair.bitcoinAddress);
  });
}

WalletAccount _wallet({required String name}) {
  return WalletAccount(
    id: '0x1111111111111111111111111111111111111111',
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

class _FakeWalletCryptoService extends WalletCryptoService {
  _FakeWalletCryptoService(this.keyPair);

  final WalletKeyPair keyPair;

  @override
  Future<WalletKeyPair> generateMnemonicWallet() async => keyPair;

  @override
  WalletKeyPair importPrivateKey(String input) => keyPair;

  @override
  WalletKeyPair importMnemonic(String input) => keyPair;

  @override
  String suiAddressFromPrivateKey(List<int> input) => keyPair.suiAddress;

  @override
  String aptosAddressFromPrivateKey(List<int> input) => keyPair.aptosAddress;

  @override
  String bitcoinAddressFromPrivateKey(String input) => keyPair.bitcoinAddress;
}

class _FakeWalletRepository extends WalletRepository {
  _FakeWalletRepository([List<WalletAccount> initialWallets = const []])
    : wallets = [...initialWallets],
      currentWalletId = initialWallets.isEmpty ? null : initialWallets.first.id;

  final List<WalletAccount> wallets;
  String? currentWalletId;
  String? savedSecretWalletId;
  String? savedPassword;

  @override
  Future<List<WalletAccount>> loadWallets() async => List.unmodifiable(wallets);

  @override
  Future<({List<WalletAccount> wallets, WalletAccount? currentWallet})>
  loadWalletSnapshot() async {
    final selected = wallets.where((wallet) => wallet.id == currentWalletId);
    return (
      wallets: List<WalletAccount>.unmodifiable(wallets),
      currentWallet: selected.isEmpty
          ? wallets.isEmpty
                ? null
                : wallets.first
          : selected.first,
    );
  }

  @override
  Future<void> saveWalletWithSecret({
    required WalletAccount wallet,
    required String password,
    required String privateKeyHex,
    String? mnemonic,
  }) async {
    savedSecretWalletId = wallet.id;
    savedPassword = password;
    final index = wallets.indexWhere((item) => item.id == wallet.id);
    if (index < 0) {
      wallets.add(wallet);
    } else {
      wallets[index] = wallet;
    }
    currentWalletId = wallet.id;
  }

  @override
  Future<void> setCurrentWalletId(String walletId) async {
    currentWalletId = walletId;
  }

  @override
  Future<void> removeWallet(String walletId) async {
    wallets.removeWhere((wallet) => wallet.id == walletId);
    if (currentWalletId == walletId) {
      currentWalletId = wallets.isEmpty ? null : wallets.first.id;
    }
  }

  @override
  Future<String?> loadCurrentWalletId() async => currentWalletId;

  @override
  Future<void> saveWallets(
    List<WalletAccount> nextWallets, {
    String? currentWalletId,
    bool allowDroppingLegacySecrets = false,
  }) async {
    wallets
      ..clear()
      ..addAll(nextWallets);
    this.currentWalletId = currentWalletId;
  }

  @override
  Future<String> readWalletPrivateKey({
    required String walletId,
    required String password,
  }) async => 'private-key';

  @override
  Future<List<int>> readWalletSuiPrivateKey({
    required String walletId,
    required String password,
  }) async => const [1];

  @override
  Future<List<int>> readWalletAptosPrivateKey({
    required String walletId,
    required String password,
  }) async => const [2];

  @override
  Future<String> readWalletBitcoinPrivateKey({
    required String walletId,
    required String password,
  }) async => 'bitcoin-private-key';
}
