import 'dart:async';

import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../utils/sensitive_data_lifecycle.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/services/config/wallet_backup_status_service.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/crypto/wallet_secret_store.dart';

/// 钱包详情页控制器。
///
/// 负责加载钱包基础信息、改名，以及在用户输入钱包密码后临时解锁私钥或助记词。
/// 控制器不会主动暴露密钥，只有明确点击查看并校验密码后才更新展示文本。
class WalletDetailController extends BaseController {
  WalletDetailController({
    WalletRepository? repository,
    WalletBackupStatusService? backupStatusService,
    this.secretRevealDuration = const Duration(seconds: 30),
  }) : _repository = repository ?? WalletRepository(),
       _backupStatusService =
           backupStatusService ?? WalletBackupStatusService();

  final WalletRepository _repository;
  final WalletBackupStatusService _backupStatusService;

  /// 私钥和助记词单次解锁后的最长展示时间。
  final Duration secretRevealDuration;

  late final void Function() _lifecycleClearCallback = clearSensitiveData;

  Timer? _privateKeyExpiryTimer;
  Timer? _privateKeyCountdownTimer;
  Timer? _mnemonicExpiryTimer;
  Timer? _mnemonicCountdownTimer;
  int _privateKeyEpoch = 0;
  int _mnemonicEpoch = 0;

  /// 当前详情页展示的钱包。
  WalletAccount? wallet;

  /// 解锁后临时展示的私钥文本，页面离开后随控制器释放。
  String _privateKeyText = '';

  String get privateKeyText => _privateKeyText;

  /// 私钥自动隐藏前的剩余秒数。
  int privateKeyRemainingSeconds = 0;

  /// 解锁后临时展示的助记词文本。
  String _mnemonicText = '';

  String get mnemonicText => _mnemonicText;

  /// 助记词自动隐藏前的剩余秒数。
  int mnemonicRemainingSeconds = 0;

  /// 当前钱包是否保存了助记词。
  bool hasMnemonic = false;

  /// 当前钱包助记词是否已完成备份确认。
  bool isMnemonicBackedUp = false;

  /// 私钥解锁请求状态，防止重复点击。
  bool isUnlockingPrivateKey = false;

  /// 助记词解锁请求状态。
  bool isUnlockingMnemonic = false;

  /// 钱包改名请求状态。
  bool isRenamingWallet = false;

  @override
  void onInit() {
    super.onInit();
    SensitiveDataLifecycle.register(_lifecycleClearCallback);
    loadWallet();
  }

  @override
  void onInactive() {
    clearSensitiveData();
  }

  @override
  void onPaused() {
    clearSensitiveData();
  }

  @override
  void onHidden() {
    clearSensitiveData();
  }

  @override
  void onDetached() {
    clearSensitiveData();
  }

  @override
  void onClose() {
    SensitiveDataLifecycle.unregister(_lifecycleClearCallback);
    clearSensitiveData(notify: false);
    super.onClose();
  }

  /// 根据路由参数中的钱包 ID 加载钱包详情。
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
              suiAddress: '',
              aptosAddress: '',
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
    isMnemonicBackedUp = wallet == null
        ? false
        : await _backupStatusService.isMnemonicBackedUp(wallet!.id);
    update();
  }

  /// 校验钱包密码并解锁私钥。
  ///
  /// 返回值用于底部弹窗判断是否关闭；失败时会显示对应 toast。
  Future<bool> unlockPrivateKey(String password) async {
    final currentWallet = wallet;
    if (currentWallet == null || isUnlockingPrivateKey) return false;
    final requestEpoch = _privateKeyEpoch;
    try {
      isUnlockingPrivateKey = true;
      update();
      final privateKey = await _repository.readWalletPrivateKey(
        walletId: currentWallet.id,
        password: password,
      );
      if (requestEpoch != _privateKeyEpoch || isClosed) return false;
      _showPrivateKey(privateKey);
      return true;
    } on WalletSecretMissingException {
      Toast.show(S.current.walletSecretMissing);
      return false;
    } on WalletSecretInvalidPasswordException {
      Toast.show(S.current.invalidWalletPassword);
      return false;
    } finally {
      isUnlockingPrivateKey = false;
      if (!isClosed) update();
    }
  }

  /// 校验钱包密码并解锁助记词。
  Future<bool> unlockMnemonic(String password) async {
    final currentWallet = wallet;
    if (currentWallet == null || isUnlockingMnemonic) return false;
    final requestEpoch = _mnemonicEpoch;
    try {
      isUnlockingMnemonic = true;
      update();
      final mnemonic = await _repository.readWalletMnemonic(
        walletId: currentWallet.id,
        password: password,
      );
      if (requestEpoch != _mnemonicEpoch || isClosed) return false;
      _showMnemonic(mnemonic);
      return true;
    } on WalletSecretMissingException {
      Toast.show(S.current.walletSecretMissing);
      return false;
    } on WalletSecretInvalidPasswordException {
      Toast.show(S.current.invalidWalletPassword);
      return false;
    } finally {
      isUnlockingMnemonic = false;
      if (!isClosed) update();
    }
  }

  /// 清除当前页面持有的全部敏感明文和倒计时。
  void clearSensitiveData({bool notify = true}) {
    final hadSensitiveData =
        _privateKeyText.isNotEmpty ||
        _mnemonicText.isNotEmpty ||
        privateKeyRemainingSeconds > 0 ||
        mnemonicRemainingSeconds > 0;
    _clearPrivateKey(notify: false);
    _clearMnemonic(notify: false);
    if (notify && hadSensitiveData && !isClosed) {
      update();
    }
  }

  void _showPrivateKey(String privateKey) {
    _clearPrivateKey(notify: false);
    _privateKeyText = privateKey;
    final epoch = _privateKeyEpoch;
    privateKeyRemainingSeconds = _remainingSeconds(secretRevealDuration);
    _privateKeyExpiryTimer = Timer(secretRevealDuration, () {
      if (epoch == _privateKeyEpoch) {
        _clearPrivateKey();
      }
    });
    _privateKeyCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (epoch != _privateKeyEpoch) return;
      privateKeyRemainingSeconds--;
      if (privateKeyRemainingSeconds <= 0) {
        privateKeyRemainingSeconds = 0;
        _privateKeyCountdownTimer?.cancel();
      }
      if (!isClosed) update();
    });
    update();
  }

  void _showMnemonic(String mnemonic) {
    _clearMnemonic(notify: false);
    _mnemonicText = mnemonic;
    final epoch = _mnemonicEpoch;
    mnemonicRemainingSeconds = _remainingSeconds(secretRevealDuration);
    _mnemonicExpiryTimer = Timer(secretRevealDuration, () {
      if (epoch == _mnemonicEpoch) {
        _clearMnemonic();
      }
    });
    _mnemonicCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (epoch != _mnemonicEpoch) return;
      mnemonicRemainingSeconds--;
      if (mnemonicRemainingSeconds <= 0) {
        mnemonicRemainingSeconds = 0;
        _mnemonicCountdownTimer?.cancel();
      }
      if (!isClosed) update();
    });
    update();
  }

  int _remainingSeconds(Duration duration) {
    return (duration.inMilliseconds / Duration.millisecondsPerSecond).ceil();
  }

  void _clearPrivateKey({bool notify = true}) {
    _privateKeyEpoch++;
    _privateKeyExpiryTimer?.cancel();
    _privateKeyCountdownTimer?.cancel();
    _privateKeyExpiryTimer = null;
    _privateKeyCountdownTimer = null;
    final changed =
        _privateKeyText.isNotEmpty || privateKeyRemainingSeconds > 0;
    _privateKeyText = '';
    privateKeyRemainingSeconds = 0;
    if (notify && changed && !isClosed) update();
  }

  void _clearMnemonic({bool notify = true}) {
    _mnemonicEpoch++;
    _mnemonicExpiryTimer?.cancel();
    _mnemonicCountdownTimer?.cancel();
    _mnemonicExpiryTimer = null;
    _mnemonicCountdownTimer = null;
    final changed = _mnemonicText.isNotEmpty || mnemonicRemainingSeconds > 0;
    _mnemonicText = '';
    mnemonicRemainingSeconds = 0;
    if (notify && changed && !isClosed) update();
  }

  /// 修改钱包名称并同步本地钱包列表。
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

  /// 从 GetX 路由参数中读取钱包 ID。
  String _walletIdFromArguments() {
    final args = Get.arguments;
    if (args is String) {
      return args;
    }
    return '';
  }
}
