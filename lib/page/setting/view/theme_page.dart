import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';
import 'package:omnicast/main.dart';

import '../../../generated/l10n.dart';
import '../controller/themes_controller.dart';

@GetXRoutePage('/theme')
/// 应用主题设置页面。
///
/// 提供跟随系统、浅色和深色三种主题模式。实际主题状态由全局
/// [ThemeController] 持有，本页面只负责展示和触发切换。
// ignore: use_key_in_widget_constructors, must_be_immutable
class ThemePage extends BaseScaffoldPage<ThemesController> {
  /// 创建主题页控制器。
  @override
  ThemesController generateController() {
    return ThemesController();
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
        onPressed: back,
      ),
      title: Text(
        S.of(context!).themeSettings,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
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

  /// 主题选项列表。
  @override
  Widget? getBody() {
    final themeController = Get.find<ThemeController>();

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
              onTap: () => themeController.setThemeMode(ThemeMode.system),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text(S.of(context!).themeSystem),
                    const Spacer(),
                    Obx(
                      () => Visibility(
                        visible:
                            themeController.themeMode.value == ThemeMode.system,
                        child: Icon(CupertinoIcons.check_mark, size: 20.r),
                      ),
                    ),
                  ],
                ),
              ),
            ).marginOnly(bottom: 16.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => themeController.setThemeMode(ThemeMode.light),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text(S.of(context!).themeLight),
                    const Spacer(),
                    Obx(
                      () => Visibility(
                        visible:
                            themeController.themeMode.value == ThemeMode.light,
                        child: Icon(CupertinoIcons.check_mark, size: 20.r),
                      ),
                    ),
                  ],
                ),
              ),
            ).marginOnly(bottom: 16.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => themeController.setThemeMode(ThemeMode.dark),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text(S.of(context!).themeDark),
                    const Spacer(),
                    Obx(
                      () => Visibility(
                        visible:
                            themeController.themeMode.value == ThemeMode.dark,
                        child: Icon(CupertinoIcons.check_mark, size: 20.r),
                      ),
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
