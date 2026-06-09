import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/models/wallet_account.dart';
import '../../../wallet/services/wallet_repository.dart';
import '../../../wallet/services/wallet_secret_store.dart';

/// 钱包详情页控制器。
///
/// 负责加载钱包基础信息、改名，以及在用户输入钱包密码后临时解锁私钥或助记词。
/// 控制器不会主动暴露密钥，只有明确点击查看并校验密码后才更新展示文本。
class WalletDetailController extends BaseController {
  WalletDetailController({WalletRepository? repository})
    : _repository = repository ?? WalletRepository();

  final WalletRepository _repository;

  /// 当前详情页展示的钱包。
  WalletAccount? wallet;

  /// 解锁后临时展示的私钥文本，页面离开后随控制器释放。
  String privateKeyText = '';

  /// 解锁后临时展示的助记词文本。
  String mnemonicText = '';

  /// 当前钱包是否保存了助记词。
  bool hasMnemonic = false;

  /// 私钥解锁请求状态，防止重复点击。
  bool isUnlockingPrivateKey = false;

  /// 助记词解锁请求状态。
  bool isUnlockingMnemonic = false;

  /// 钱包改名请求状态。
  bool isRenamingWallet = false;

  @override
  void onInit() {
    super.onInit();
    loadWallet();
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

  /// 校验钱包密码并解锁私钥。
  ///
  /// 返回值用于底部弹窗判断是否关闭；失败时会显示对应 toast。
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

  /// 校验钱包密码并解锁助记词。
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
