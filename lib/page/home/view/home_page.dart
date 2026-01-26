import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../events/text_event.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../main.dart';
import '../../../utils/global_extension.dart';
import '../../../utils/storage.dart';
import '../../../utils/toast_util.dart';

@GetXRoutePage('/home')
class HomePage extends BaseScaffoldPage<HomePageController> {
  @override
  HomePageController generateController() {
    return HomePageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      title: Text("OmniCast"),
      actions: [
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () {
            // 处理设置按钮点击事件
            Get.toNamed(RouteTable.setting);
          },
        ),
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
        SvgPicture.asset(
          'assets/svg/safety.svg',
          width: 40.h,
          height: 40.h,
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () async {},
          child: Text(S.of(context!).phone),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () async {},
          child: const Text("Http mock example"),
        ).marginOnly(bottom: 10.h),
        ElevatedButton(
          onPressed: () async {},
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
          child: Obx(
            () => Text(
              themeController.themeMode.value == ThemeMode.light
                  ? "切换到深色主题 / Dark Mode"
                  : "切换到浅色主题 / Light Mode",
            ),
          ),
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
