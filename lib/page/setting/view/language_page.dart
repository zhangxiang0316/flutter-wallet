import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../common/theme/app_theme_extension.dart';
import '../../../utils/storage.dart';

@GetXRoutePage('/language')
class LanguagePage extends BaseScaffoldPage<LanguageController> {
  @override
  LanguageController generateController() {
    return LanguageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      title: Text('应用语言', style: TextStyle(fontWeight: FontWeight.w700)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Get.back(),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context!).cardColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => controller.switchLanguage('zh'),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text('中文'),
                    Spacer(),
                    Visibility(
                      visible: controller.currentLanguage == '中文',
                      child: Icon(CupertinoIcons.check_mark, size: 20.r),
                    ),
                  ],
                ),
              ),
            ).marginOnly(bottom: 16.h),
            GestureDetector(
              onTap: () => controller.switchLanguage("en"),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text('English'),
                    Spacer(),
                    Visibility(
                      visible: controller.currentLanguage == 'English',
                      child: Icon(CupertinoIcons.check_mark, size: 20.r),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageController extends BaseController {
  // 当前语言显示
  final currentLanguage = ''.obs;
  final _storage = Storage();
  static const String _languageKey = 'app_language';
  @override
  void onInit() {
    super.onInit();
    _loadSavedLanguage();
  }

  /// 加载保存的语言设置
  Future<void> _loadSavedLanguage() async {
    final savedLanguage = await _storage.getStorage(_languageKey);
    if (savedLanguage != null && savedLanguage.isNotEmpty) {
      final locale = _getLocaleFromString(savedLanguage);
      await Get.updateLocale(locale);
      _updateLanguageDisplay(locale);
    } else {
      // 如果没有保存的语言，使用系统语言
      _updateLanguageDisplay(Get.locale ?? const Locale('zh'));
    }
  }

  /// 切换语言
  Future<void> switchLanguage(String languageCode) async {
    final newLocale = languageCode == 'zh'
        ? const Locale('zh')
        : const Locale('en');

    // 更新语言
    await Get.updateLocale(newLocale);

    // 保存语言设置
    await _storage.setStorage(_languageKey, newLocale.languageCode);

    // 更新显示
    _updateLanguageDisplay(newLocale);
  }

  /// 更新语言显示
  void _updateLanguageDisplay(Locale locale) {
    currentLanguage.value = locale.languageCode == 'zh' ? '中文' : 'English';
    update();
  }

  /// 从字符串获取Locale对象
  Locale _getLocaleFromString(String languageCode) {
    return Locale(languageCode);
  }
}
