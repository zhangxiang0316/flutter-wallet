import 'package:flutter/material.dart';
import 'package:omnicast/generated/l10n.dart';
import 'package:omnicast/router/route_table.dart';
import 'package:omnicast/utils/global_extension.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import '../base/base_controller.dart';
import '../base/base_scaffold_page.dart';
import '../events/text_event.dart';
import '../main.dart';
import '../utils/log_util.dart';
import '../utils/toast_util.dart';
import '../utils/storage.dart';

@GetXRoutePage("/home")
class HomePage extends BaseScaffoldPage<HomePageController> {
  @override
  HomePageController generateController() {
    return HomePageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    final themeController = Get.find<ThemeController>();
    return AppBar(
      title: Text('111111'),
      actions: [
        // 显示当前主题
        Center(
          child: Obx(
            () => Icon(
              themeController.themeMode.value == ThemeMode.light 
                  ? Icons.light_mode 
                  : Icons.dark_mode,
              size: 20,
            ),
          ),
        ).marginOnly(right: 10.w),
        // 显示当前语言
        Center(
          child: Obx(
            () => Text(
              controller.currentLanguage.value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ).marginOnly(right: 10.w),
      ],
    );
  }

  @override
  Widget? getBody() {
    final themeController = Get.find<ThemeController>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () async {
            Get.toNamed(RouteTable.event);
          },
          child: Text(S.of(context!).phone),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () async {
            Get.toNamed(RouteTable.http);
          },
          child: const Text("Http mock example"),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () async {
            Get.toNamed(RouteTable.lightStorage);
          },
          child: const Text("lightStorage example"),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () async {
            Get.toNamed(
              RouteTable.test,
              arguments: {'id': 123, 'name': 'test'},
            );
          },
          child: const Text("Test"),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () {
            controller.switchLanguage();
          },
          child: const Text("切换语言 / Switch Language"),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () {
            themeController.switchTheme();
          },
          child: Obx(() => Text(
            themeController.themeMode.value == ThemeMode.light
                ? "切换到深色主题 / Dark Mode"
                : "切换到浅色主题 / Light Mode",
          )),
        ).marginOnly(bottom: 10.h),
      ],
    ).align(Alignment.center);
  }
}

class HomePageController extends BaseController {
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
  Future<void> switchLanguage() async {
    final currentLocale = Get.locale ?? const Locale('zh');
    final newLocale = currentLocale.languageCode == 'zh'
        ? const Locale('en')
        : const Locale('zh');

    // 更新语言
    await Get.updateLocale(newLocale);

    // 保存语言设置
    await _storage.setStorage(_languageKey, newLocale.languageCode);

    // 更新显示
    _updateLanguageDisplay(newLocale);

    Toast.show(
      newLocale.languageCode == 'zh' ? '已切换到中文' : 'Switched to English',
    );
  }

  /// 更新语言显示
  void _updateLanguageDisplay(Locale locale) {
    currentLanguage.value = locale.languageCode == 'zh' ? '中文' : 'English';
  }

  /// 从字符串获取Locale对象
  Locale _getLocaleFromString(String languageCode) {
    return Locale(languageCode);
  }

  @override
  List<Type> getListenEvent() {
    return [CustomTextEvent];
  }

  @override
  void onReceiveEvent(event) {
    print("---1111111----${event.text}");
    switch (event.runtimeType) {
      case CustomTextEvent:
        Toast.show(event.text);
        break;
      default:
    }
  }

}
