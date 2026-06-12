import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../utils/storage.dart';

@GetXRoutePage('/language')
/// 应用语言设置页面。
///
/// 提供中文和英文两个选项，选择后立即更新 GetX Locale，并把语言代码保存到
/// 本地存储，供下次启动时恢复。
class LanguagePage extends BaseScaffoldPage<LanguageController> {
  /// 创建语言设置控制器。
  @override
  LanguageController generateController() {
    return LanguageController();
  }

  /// 页面顶部导航栏。
  @override
  PreferredSizeWidget? getAppBar() {
    final colorScheme = Theme.of(context!).colorScheme;
    final dividerColor = colorScheme.outline.withValues(alpha: 0.12);
    return AppBar(
      backgroundColor: Theme.of(context!).cardColor,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 50.h,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
        onPressed: Get.back,
      ),
      centerTitle: true,
      title: Text(
        '应用语言',
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(
          1 / MediaQuery.of(context!).devicePixelRatio,
        ),
        child: Container(
          height: 1 / MediaQuery.of(context!).devicePixelRatio,
          color: dividerColor,
        ),
      ),
    );
  }

  /// 语言选项列表。
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
                      visible: controller.currentLanguage.value == '中文',
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
                      visible: controller.currentLanguage.value == 'English',
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

  /// 切换语言。
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
