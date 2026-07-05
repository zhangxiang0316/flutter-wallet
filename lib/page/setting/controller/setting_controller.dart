import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../main.dart';
import '../../../utils/storage.dart';

/// 设置页控制器。
///
/// 负责读取并展示当前语言和主题。真正的切换逻辑分别在语言页和主题页完成。
class SettingController extends BaseController {
  /// 当前语言展示文本。
  final currentLanguage = ''.obs;

  final _storage = Storage();
  static const String _languageKey = 'app_language';

  /// 全局主题控制器。
  final themeController = Get.find<ThemeController>();

  /// 当前主题展示文本。
  final theme = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLanguage();
    _syncThemeDisplay();
  }

  /// 页面重新激活时刷新摘要，确保从子页面返回后展示最新值。
  @override
  void onPageActive() {
    super.onPageActive();
    _loadSavedLanguage();
    _syncThemeDisplay();
  }

  /// 加载保存的语言设置。
  Future<void> _loadSavedLanguage() async {
    final savedLanguage = await _storage.getString(_languageKey);
    if (savedLanguage != null && savedLanguage.isNotEmpty) {
      final locale = _getLocaleFromString(savedLanguage);
      await Get.updateLocale(locale);
      _updateLanguageDisplay(locale);
    } else {
      _updateLanguageDisplay(Get.locale ?? const Locale('zh'));
    }
  }

  /// 更新语言显示。
  void _updateLanguageDisplay(Locale locale) {
    currentLanguage.value = locale.languageCode == 'zh' ? '中文' : 'English';
  }

  /// 将当前主题模式转换为本地化展示文本。
  void _syncThemeDisplay() {
    theme.value = themeController.themeMode.value == ThemeMode.dark
        ? S.current.themeDark
        : themeController.themeMode.value == ThemeMode.light
        ? S.current.themeLight
        : S.current.themeSystem;
  }

  /// 将存储中的语言代码转换为 Locale。
  Locale _getLocaleFromString(String languageCode) {
    return Locale(languageCode);
  }
}
