import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';
import 'package:omnicast/main.dart';

import '../../../base/base_controller.dart';
import '../../../common/theme/app_theme_extension.dart';

@GetXRoutePage('/theme')
/// 应用主题设置页面。
///
/// 提供跟随系统、浅色和深色三种主题模式。实际主题状态由全局
/// [ThemeController] 持有，本页面只负责展示和触发切换。
class ThemePage extends BaseScaffoldPage<ThemesController> {
  /// 创建主题页控制器。
  @override
  ThemesController generateController() {
    return ThemesController();
  }

  /// 页面顶部导航栏。
  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => back(),
      ),
      title: Text('主题设置', style: TextStyle(fontWeight: FontWeight.w700)),
      centerTitle: true,
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
                    Text('跟随系统'),
                    Spacer(),
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
                    Text('浅色主题'),
                    Spacer(),
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
                    Text('深色主题'),
                    Spacer(),
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

/// 主题页控制器。
///
/// 当前只暴露主题扩展对象，便于后续如果页面需要读取品牌色或语义色时复用。
class ThemesController extends BaseController {
  /// 当前上下文中的主题扩展。
  final appTheme = Theme.of(Get.context!).extension<AppThemeExtension>()!;
}
