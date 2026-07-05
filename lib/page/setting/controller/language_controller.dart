import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../utils/storage.dart';

/// 语言设置控制器。
///
/// 负责读取本地保存的语言代码、切换应用 Locale，并维护页面展示的当前语言文本。
class LanguageController extends BaseController {
  /// 当前语言显示文本。
  final currentLanguage = ''.obs;

  final _storage = Storage();
  static const String _languageKey = 'app_language';

  /// 初始化时恢复上次保存的语言。
  @override
  void onInit() {
    super.onInit();
    _loadSavedLanguage();
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

  /// 切换语言。
  Future<void> switchLanguage(String languageCode) async {
    final newLocale = languageCode == 'zh'
        ? const Locale('zh')
        : const Locale('en');
    await Get.updateLocale(newLocale);
    await _storage.setString(_languageKey, newLocale.languageCode);
    _updateLanguageDisplay(newLocale);
  }

  /// 更新语言显示。
  void _updateLanguageDisplay(Locale locale) {
    currentLanguage.value = locale.languageCode == 'zh' ? '中文' : 'English';
    update();
  }

  /// 从字符串获取 Locale 对象。
  Locale _getLocaleFromString(String languageCode) {
    return Locale(languageCode);
  }
}
