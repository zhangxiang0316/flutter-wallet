import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../controller/language_controller.dart';

@GetXRoutePage('/language')
/// 应用语言设置页面。
///
/// 提供中文和英文两个选项，选择后立即更新 GetX Locale，并把语言代码保存到
/// 本地存储，供下次启动时恢复。
// ignore: use_key_in_widget_constructors, must_be_immutable
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
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.switchLanguage('zh'),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    const Text('中文'),
                    const Spacer(),
                    Visibility(
                      visible: controller.currentLanguage.value == '中文',
                      child: Icon(CupertinoIcons.check_mark, size: 20.r),
                    ),
                  ],
                ),
              ),
            ).marginOnly(bottom: 16.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.switchLanguage('en'),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    const Text('English'),
                    const Spacer(),
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
