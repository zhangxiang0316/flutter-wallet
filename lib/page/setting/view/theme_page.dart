import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';
import 'package:omnicast/main.dart';

import '../../../base/base_controller.dart';
import '../../../common/theme/app_theme_extension.dart';

@GetXRoutePage('/theme')
class ThemePage extends BaseScaffoldPage<ThemesController> {
  @override
  ThemesController generateController() {
    return ThemesController();
  }

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
              onTap: () => themeController.switchTheme(),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text('浅色主题'),
                    Spacer(),
                    Visibility(
                      visible:
                          themeController.themeMode.value == ThemeMode.light,
                      child: Icon(CupertinoIcons.check_mark, size: 20.r),
                    ),
                  ],
                ),
              ),
            ).marginOnly(bottom: 16.h),
            GestureDetector(
              onTap: () => themeController.switchTheme(),
              child: Container(
                padding: EdgeInsets.all(5.h),
                child: Row(
                  children: [
                    Text('深色主题'),
                    Spacer(),
                    Visibility(
                      visible:
                          themeController.themeMode.value == ThemeMode.dark,
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

class ThemesController extends BaseController {
  final appTheme = Theme.of(Get.context!).extension<AppThemeExtension>()!;
}
