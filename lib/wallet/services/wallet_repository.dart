import 'dart:async';

import '../../utils/storage.dart';
import '../models/wallet_account.dart';
import '../models/wallet_key_material.dart';
import 'crypto/wallet_crypto_service.dart';
import 'crypto/wallet_secret_store.dart';
import 'wallet_local_data_cleanup_service.dart';
import 'wallet_persistence_coordinator.dart';

/// 钱包仓储服务。
///
/// 该服务是钱包元数据和密钥存储之间的协调层：
/// - 钱包列表、当前钱包 ID 等非敏感信息存放在普通本地存储；
/// - 私钥、助记词等敏感信息委托 [WalletSecretStore] 加密保存；
/// - 兼容旧版本单钱包数据，并提供明文私钥迁移入口。
///
/// 页面和控制器通常只依赖该仓储，不直接操作底层 storage 或 secure storage。
class WalletRepository {
  /// 创建钱包仓储。
  ///
  /// 测试时可以注入存储、密钥仓库和加密服务；业务场景使用默认实现。
  WalletRepository({
    KeyValueStorage? storage,
    WalletSecretStore? secretStore,
    WalletCryptoService? cryptoService,
    WalletLocalDataCleanupService? cleanupService,
    Map<String, WalletKeyMaterialReader> keyMaterialReaders = const {},
  }) : _storage = storage ?? Storage(),
       _secretStore = secretStore ?? WalletSecretStore(),
       _cryptoService = cryptoService ?? WalletCryptoService() {
    _persistence = WalletPersistenceCoordinator(
      storage: _storage,
      secretStore: _secretStore,
      cleanupService: cleanupService ?? WalletLocalDataCleanupService(),
      writeWalletState: _writeWalletStateRaw,
    );
    _keyMaterialReaders = {
      WalletAddressNamespace.evm: _readEvmKeyMaterial,
      WalletAddressNamespace.solana: _readSolanaKeyMaterial,
      WalletAddressNamespace.sui: _readSuiKeyMaterial,
      WalletAddressNamespace.aptos: _readAptosKeyMaterial,
      WalletAddressNamespace.bitcoin: _readBitcoinKeyMaterial,
      ...keyMaterialReaders,
    };
  }

  /// 钱包元数据存储。
  final KeyValueStorage _storage;

  /// 私钥和助记词加密存储。
  final WalletSecretStore _secretStore;

  /// 用于从助记词或私钥派生 Solana 私钥。
  final WalletCryptoService _cryptoService;

  late final WalletPersistenceCoordinator _persistence;
  late final Map<String, WalletKeyMaterialReader> _keyMaterialReaders;

  /// 所有仓储实例共享的进程内写屏障，避免一个实例把另一个实例正在执行的 journal
  /// 当成启动残留事务恢复。
  static Future<void> _persistenceBarrier = Future<void>.value();

  /// 旧版本单钱包存储 key。
  ///
  /// 现在主要用于兼容迁移，正常多钱包数据写入 [_walletsKey]。
  static const String _walletKey = 'crypto_wallet_account';

  /// 多钱包列表存储 key。
  static const String _walletsKey = 'crypto_wallet_accounts';

  /// 当前选中钱包 ID 存储 key。
  static const String _currentWalletIdKey = 'crypto_current_wallet_id';

  /// 加载所有钱包元数据。
  ///
  /// 优先读取新版本多钱包列表；如果不存在，则尝试读取旧版本单钱包数据，方便旧用户
  /// 进入迁移流程。这里不会读取私钥或助记词。
  Future<List<WalletAccount>> loadWallets() async {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      return _loadWalletsRaw();
    });
  }

  Future<List<WalletAccount>> _loadWalletsRaw() async {
    final walletsJson = await _storage.getJsonList(_walletsKey);
    if (walletsJson != null) {
      return walletsJson
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

  /// 一次读取钱包列表和当前钱包，避免启动时分别解析同一份钱包 JSON。
  Future<({List<WalletAccount> wallets, WalletAccount? currentWallet})>
  loadWalletSnapshot() async {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      final wallets = await _loadWalletsRaw();
      if (wallets.isEmpty) {
        return (wallets: wallets, currentWallet: null);
      }
      final currentId = await _loadCurrentWalletIdRaw();
      final currentWallet = wallets.firstWhere(
        (wallet) => wallet.id == currentId,
        orElse: () => wallets.first,
      );
      return (wallets: wallets, currentWallet: currentWallet);
    });
  }

  /// 加载当前选中的钱包。
  ///
  /// 如果当前钱包 ID 丢失或找不到对应钱包，则退回到列表第一个钱包。
  Future<WalletAccount?> loadCurrentWallet() async {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      final wallets = await _loadWalletsRaw();
      if (wallets.isEmpty) return null;
      final currentId = await _loadCurrentWalletIdRaw();
      return wallets.firstWhere(
        (wallet) => wallet.id == currentId,
        orElse: () => wallets.first,
      );
    });
  }

  /// 读取当前钱包 ID。
  Future<String?> loadCurrentWalletId() async {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      return _loadCurrentWalletIdRaw();
    });
  }

  Future<String?> _loadCurrentWalletIdRaw() async {
    final currentWalletId = await _storage.getString(_currentWalletIdKey);
    if (currentWalletId != null && currentWalletId.isNotEmpty) {
      return currentWalletId;
    }
    return null;
  }

  /// 保存钱包列表。
  ///
  /// 默认情况下，如果列表中仍存在旧版本明文私钥字段，会拒绝保存，防止在普通存储中
  /// 继续保留敏感信息。只有迁移流程可以通过 [allowDroppingLegacySecrets] 放行。
  Future<void> saveWallets(
    List<WalletAccount> wallets, {
    String? currentWalletId,
    bool allowDroppingLegacySecrets = false,
  }) async {
    await _serialized(() async {
      await _persistence.recoverPendingTransaction();
      _validateWalletsForSave(
        wallets,
        allowDroppingLegacySecrets: allowDroppingLegacySecrets,
      );
      await _storage.setJsonList(
        _walletsKey,
        wallets.map((wallet) => wallet.toJson()).toList(),
      );
      if (currentWalletId != null && currentWalletId.isNotEmpty) {
        await _storage.setString(_currentWalletIdKey, currentWalletId);
      }
    });
  }

  /// 新增或更新一个钱包，并把它设为当前钱包。
  Future<void> saveWallet(WalletAccount wallet) async {
    await _serialized(() async {
      await _persistence.recoverPendingTransaction();
      final wallets = [...await _loadWalletsRaw()];
      _upsertWallet(wallets, wallet);
      await _writeWalletStateRaw(wallets, wallet.id);
    });
  }

  /// 使用 staging 密钥和持久化 journal 原子地新增或更新钱包。
  Future<void> saveWalletWithSecret({
    required WalletAccount wallet,
    required String password,
    required String privateKeyHex,
    String? mnemonic,
  }) {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      final previousWallets = await _loadWalletsRaw();
      _validateWalletsForSave(
        previousWallets,
        allowDroppingLegacySecrets: false,
      );
      await _persistence.ensureNoPendingTransaction();
      final previousCurrentWalletId = await _loadCurrentWalletIdRaw();
      await _persistence.upsert(
        wallet: wallet,
        password: password,
        privateKeyHex: privateKeyHex,
        mnemonic: mnemonic,
        previousWallets: previousWallets,
        previousCurrentWalletId: previousCurrentWalletId,
      );
    });
  }

  /// 修改钱包名称。
  ///
  /// 空名称和不存在的钱包会返回 null。保存时尽量保留当前钱包 ID，不因为重命名改变选择状态。
  Future<WalletAccount?> renameWallet({
    required String walletId,
    required String name,
  }) async {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) return null;
      final wallets = [...await _loadWalletsRaw()];
      final index = wallets.indexWhere((item) => item.id == walletId);
      if (index < 0) return null;
      final nextWallet = wallets[index].copyWith(name: trimmedName);
      wallets[index] = nextWallet;
      await _writeWalletStateRaw(
        wallets,
        await _loadCurrentWalletIdRaw() ?? walletId,
      );
      return nextWallet;
    });
  }

  /// 保存钱包密钥。
  ///
  /// 私钥必存；助记词仅在创建/助记词导入钱包时存在。私钥和助记词会分别加密保存，
  /// 钱包元数据中不存放明文敏感信息。
  Future<void> saveWalletSecret({
    required String walletId,
    required String password,
    required String privateKeyHex,
    String? mnemonic,
  }) async {
    final normalizedMnemonic = mnemonic?.trim() ?? '';
    await Future.wait<void>([
      _secretStore.savePrivateKey(
        walletId: walletId,
        password: password,
        privateKeyHex: privateKeyHex,
      ),
      if (normalizedMnemonic.isNotEmpty)
        _secretStore.saveMnemonic(
          walletId: walletId,
          password: password,
          mnemonic: normalizedMnemonic,
        ),
    ]);
  }

  /// 使用密码读取钱包私钥。
  Future<String> readWalletPrivateKey({
    required String walletId,
    required String password,
  }) {
    return _secretStore.readPrivateKey(walletId: walletId, password: password);
  }

  /// 使用密码读取钱包助记词。
  ///
  /// 私钥导入的钱包通常没有助记词，会由 [WalletSecretStore] 抛出缺失异常。
  Future<String> readWalletMnemonic({
    required String walletId,
    required String password,
  }) {
    return _secretStore.readMnemonic(walletId: walletId, password: password);
  }

  /// Resolve signing material through the namespace declared by the adapter.
  /// New chains can inject another reader without changing transfer pages.
  Future<WalletKeyMaterial> readWalletKeyMaterial({
    required String namespace,
    required String walletId,
    required String password,
  }) {
    final reader = _keyMaterialReaders[namespace];
    if (reader == null) {
      throw StateError('No key material reader registered for $namespace');
    }
    return reader(walletId: walletId, password: password);
  }

  Future<WalletKeyMaterial> _readEvmKeyMaterial({
    required String walletId,
    required String password,
  }) async {
    return WalletKeyMaterial(
      privateKeyHex: await readWalletPrivateKey(
        walletId: walletId,
        password: password,
      ),
    );
  }

  Future<WalletKeyMaterial> _readSolanaKeyMaterial({
    required String walletId,
    required String password,
  }) async {
    final privateKey = await readWalletPrivateKey(
      walletId: walletId,
      password: password,
    );
    return WalletKeyMaterial(
      privateKeyHex: privateKey,
      signingKeyBytes: await readWalletSolanaPrivateKey(
        walletId: walletId,
        password: password,
      ),
    );
  }

  Future<WalletKeyMaterial> _readSuiKeyMaterial({
    required String walletId,
    required String password,
  }) async {
    final privateKey = await readWalletPrivateKey(
      walletId: walletId,
      password: password,
    );
    return WalletKeyMaterial(
      privateKeyHex: privateKey,
      signingKeyBytes: await readWalletSuiPrivateKey(
        walletId: walletId,
        password: password,
      ),
    );
  }

  Future<WalletKeyMaterial> _readAptosKeyMaterial({
    required String walletId,
    required String password,
  }) async {
    final privateKey = await readWalletPrivateKey(
      walletId: walletId,
      password: password,
    );
    return WalletKeyMaterial(
      privateKeyHex: privateKey,
      signingKeyBytes: await readWalletAptosPrivateKey(
        walletId: walletId,
        password: password,
      ),
    );
  }

  Future<WalletKeyMaterial> _readBitcoinKeyMaterial({
    required String walletId,
    required String password,
  }) async {
    return WalletKeyMaterial(
      privateKeyHex: await readWalletBitcoinPrivateKey(
        walletId: walletId,
        password: password,
      ),
    );
  }

  /// 读取 Solana 转账所需的 Ed25519 私钥 seed。
  ///
  /// 助记词钱包优先使用助记词按 Solana 路径派生；如果钱包没有助记词，则回退到
  /// 导入私钥兼容规则，即把 EVM 私钥字节作为 Solana seed。
  Future<List<int>> readWalletSolanaPrivateKey({
    required String walletId,
    required String password,
  }) async {
    try {
      final mnemonic = await readWalletMnemonic(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.solanaPrivateKeyFromMnemonic(mnemonic);
    } on WalletSecretMissingException {
      final privateKeyHex = await readWalletPrivateKey(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.solanaPrivateKeyFromPrivateKey(privateKeyHex);
    }
  }

  /// 读取 Sui 转账所需的 Ed25519 私钥 seed。
  ///
  /// 助记词钱包按 Sui 的 `m/44'/784'/0'/0'/0'` 路径派生；私钥导入钱包
  /// 复用导入的 32 字节私钥作为 Ed25519 seed。
  Future<List<int>> readWalletSuiPrivateKey({
    required String walletId,
    required String password,
  }) async {
    try {
      final mnemonic = await readWalletMnemonic(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.suiPrivateKeyFromMnemonic(mnemonic);
    } on WalletSecretMissingException {
      final privateKeyHex = await readWalletPrivateKey(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.suiPrivateKeyFromPrivateKey(privateKeyHex);
    }
  }

  Future<List<int>> readWalletAptosPrivateKey({
    required String walletId,
    required String password,
  }) async {
    try {
      final mnemonic = await readWalletMnemonic(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.aptosPrivateKeyFromMnemonic(mnemonic);
    } on WalletSecretMissingException {
      final privateKeyHex = await readWalletPrivateKey(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.aptosPrivateKeyFromPrivateKey(privateKeyHex);
    }
  }

  /// 读取 Bitcoin P2WPKH 转账所需的 secp256k1 私钥。
  ///
  /// 助记词钱包按 BIP84 路径派生；私钥导入钱包复用导入的原始私钥。
  Future<String> readWalletBitcoinPrivateKey({
    required String walletId,
    required String password,
  }) async {
    try {
      final mnemonic = await readWalletMnemonic(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.bitcoinPrivateKeyFromMnemonic(mnemonic);
    } on WalletSecretMissingException {
      final privateKeyHex = await readWalletPrivateKey(
        walletId: walletId,
        password: password,
      );
      return _cryptoService.bitcoinPrivateKeyFromPrivateKey(privateKeyHex);
    }
  }

  /// 判断钱包是否存在助记词。
  Future<bool> hasWalletMnemonic(String walletId) {
    return _secretStore.hasMnemonic(walletId);
  }

  /// 是否存在旧版本明文私钥钱包。
  Future<bool> hasLegacyPlainSecrets() async {
    final wallets = await loadWallets();
    return wallets.any((wallet) => wallet.needsSecretMigration);
  }

  /// 迁移旧版本明文私钥。
  ///
  /// 旧钱包的 privateKeyHex 存在普通存储中。迁移时用用户输入的密码加密保存到
  /// [WalletSecretStore]，然后重写钱包列表以清理明文字段，最后删除旧单钱包 key。
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
    await _storage.remove(_walletKey);
  }

  /// 设置当前钱包 ID。
  Future<void> setCurrentWalletId(String walletId) {
    return _serialized(() async {
      await _persistence.recoverPendingTransaction();
      await _storage.setString(_currentWalletIdKey, walletId);
    });
  }

  /// 删除钱包。
  ///
  /// 删除元数据后同步删除对应私钥和助记词。如果删掉的是当前钱包，会自动切到列表第一个；
  /// 如果没有钱包了，则清空当前钱包 ID。
  Future<void> removeWallet(String walletId) async {
    await _serialized(() async {
      await _persistence.recoverPendingTransaction();
      final previousWallets = await _loadWalletsRaw();
      _validateWalletsForSave(
        previousWallets,
        allowDroppingLegacySecrets: false,
      );
      await _persistence.ensureNoPendingTransaction();
      final previousCurrentWalletId = await _loadCurrentWalletIdRaw();
      await _persistence.remove(
        walletId: walletId,
        previousWallets: previousWallets,
        previousCurrentWalletId: previousCurrentWalletId,
      );
    });
  }

  Future<void> _writeWalletStateRaw(
    List<WalletAccount> wallets,
    String? currentWalletId,
  ) async {
    await _storage.setJsonList(
      _walletsKey,
      wallets.map((wallet) => wallet.toJson()).toList(growable: false),
    );
    if (currentWalletId == null || currentWalletId.isEmpty) {
      await _storage.remove(_currentWalletIdKey);
    } else {
      await _storage.setString(_currentWalletIdKey, currentWalletId);
    }
  }

  void _upsertWallet(List<WalletAccount> wallets, WalletAccount wallet) {
    final index = wallets.indexWhere((item) => item.id == wallet.id);
    if (index < 0) {
      wallets.add(wallet);
    } else {
      wallets[index] = wallet;
    }
  }

  void _validateWalletsForSave(
    List<WalletAccount> wallets, {
    required bool allowDroppingLegacySecrets,
  }) {
    if (!allowDroppingLegacySecrets &&
        wallets.any((wallet) => wallet.needsSecretMigration)) {
      throw StateError('Legacy wallet secrets must be migrated before saving');
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _persistenceBarrier;
    final completed = Completer<void>();
    _persistenceBarrier = completed.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        completed.complete();
      }
    }();
  }

  /// 读取旧版本单钱包数据。
  ///
  /// 仅作为兼容入口，不会再向该 key 写入新数据。
  Future<WalletAccount?> _loadLegacyWallet() async {
    final walletJson = await _storage.getJsonMap(_walletKey);
    if (walletJson != null) {
      return WalletAccount.fromJson(walletJson);
    }
    return null;
  }
}
