import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../utils/password_cache_service.dart';
import '../../../utils/toast_util.dart';

/// 密码缓存设置控制器。
///
/// 负责读取/保存密码缓存的启用状态和过期时间，页面只消费 Observable 状态。
class PasswordCacheSettingsController extends BaseController {
  /// 密码缓存是否启用。
  final isEnabled = true.obs;

  /// 缓存过期时间（分钟）。
  final expiryMinutes = 5.obs;

  /// 是否正在加载初始配置。
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  /// 加载本地保存的密码缓存配置。
  Future<void> _loadSettings() async {
    final enabled = await PasswordCacheService.isEnabled();
    final expiry = await PasswordCacheService.getExpiryMinutes();
    isEnabled.value = enabled;
    expiryMinutes.value = expiry;
    isLoading.value = false;
  }

  /// 切换密码缓存启用状态。
  Future<void> toggleEnabled(bool value) async {
    await PasswordCacheService.setEnabled(value);
    isEnabled.value = value;
    Toast.show(
      value ? S.current.passwordCacheEnabled : S.current.passwordCacheDisabled,
    );
  }

  /// 设置缓存过期时间。
  Future<void> setExpiryMinutes(int minutes) async {
    await PasswordCacheService.setExpiryMinutes(minutes);
    expiryMinutes.value = minutes;
  }
}
