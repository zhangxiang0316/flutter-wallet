import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../generated/route_table.dart';
import '../../../utils/global_extension.dart';
import '../../../utils/storage.dart';

@GetXRoutePage('/setting')
class SettingPage extends BaseScaffoldPage<SettingController> {
  @override
  SettingController generateController() {
    return SettingController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.arrow_back).onTab(() {
        Get.back();
      }),
      centerTitle: true,
      title: const Text("设置", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context!).cardColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Center(child: Text('飞')),
                ).marginOnly(right: 10.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('张飞').marginOnly(bottom: 4.h),
                    Text('zhangfei@qq.com'),
                  ],
                ),
              ],
            ),
          ).marginOnly(bottom: 15.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context!).cardColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Get.toNamed(RouteTable.language),
                  child: Row(
                    children: [
                      Text('语言'),
                      Spacer(),
                      Obx(() => Text(controller.currentLanguage.value)),
                      SizedBox(width: 10.w),
                      Icon(Icons.arrow_forward_ios, size: 16.r),
                    ],
                  ),
                ).marginOnly(bottom: 16.h),
                GestureDetector(
                  onTap: () => Get.toNamed(RouteTable.theme),
                  child: Row(
                    children: [
                      Text('主题'),
                      Spacer(),
                      Text('亮色'),
                      SizedBox(width: 10.w),
                      Icon(Icons.arrow_forward_ios, size: 16.r),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingController extends BaseController {
  final currentLanguage = ''.obs;
  final _storage = Storage();
  static const String _languageKey = 'app_language';

  @override
  void onPageActive() {
    super.onPageActive();
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

  /// 更新语言显示
  void _updateLanguageDisplay(Locale locale) {
    currentLanguage.value = locale.languageCode == 'zh' ? '中文' : 'English';
  }

  Locale _getLocaleFromString(String languageCode) {
    return Locale(languageCode);
  }
}
