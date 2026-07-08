import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../controller/password_cache_settings_controller.dart';
import 'widgets/cell_group.dart';
import 'widgets/expiry_option.dart';
import 'widgets/note_cell.dart';
import 'widgets/switch_cell.dart';

@GetXRoutePage('/passwordCacheSettings')
/// 密码缓存设置页面。
///
/// 允许用户配置密码缓存功能：开启/关闭密码缓存、选择缓存过期时间（1/5/10/30分钟）。
// ignore: use_key_in_widget_constructors, must_be_immutable
class PasswordCacheSettingsPage
    extends BaseScaffoldPage<PasswordCacheSettingsController> {
  @override
  PasswordCacheSettingsController generateController() {
    return PasswordCacheSettingsController();
  }

  @override
  PreferredSizeWidget? getAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).cardColor,
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
        S.of(context).securitySettings,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget? getBody(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      child: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
          children: [
            CellGroup(
              children: [
                SwitchCell(
                  title: S.of(context).passwordCache,
                  subtitle: S.of(context).passwordCacheDesc,
                  value: controller.isEnabled.value,
                  onChanged: controller.toggleEnabled,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: controller.isEnabled.value
                  ? CellGroup(
                      key: const ValueKey('expiry-options'),
                      title: S.of(context).passwordCacheExpiry,
                      children: [
                        ExpiryOption(
                          title: S.of(context).passwordCacheExpiry1,
                          selected: controller.expiryMinutes.value == 1,
                          onTap: () => controller.setExpiryMinutes(1),
                        ),
                        ExpiryOption(
                          title: S.of(context).passwordCacheExpiry5,
                          selected: controller.expiryMinutes.value == 5,
                          onTap: () => controller.setExpiryMinutes(5),
                        ),
                        ExpiryOption(
                          title: S.of(context).passwordCacheExpiry10,
                          selected: controller.expiryMinutes.value == 10,
                          onTap: () => controller.setExpiryMinutes(10),
                        ),
                        ExpiryOption(
                          title: S.of(context).passwordCacheExpiry30,
                          selected: controller.expiryMinutes.value == 30,
                          onTap: () => controller.setExpiryMinutes(30),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('expiry-hidden')),
            ),
            SizedBox(height: 12.h),
            CellGroup(
              title: S.of(context).passwordCacheSecurityNoteTitle,
              children: [
                NoteCell(text: S.of(context).passwordCacheMemoryOnly),
                NoteCell(text: S.of(context).passwordCacheClearedOnExit),
                NoteCell(text: S.of(context).passwordCacheExpiresAutomatically),
              ],
            ),
          ],
        );
      }),
    );
  }
}
