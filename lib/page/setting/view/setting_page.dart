import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../main.dart';
import '../../../utils/global_extension.dart';
import '../../../utils/storage.dart';

@GetXRoutePage('/setting')
// ignore: use_key_in_widget_constructors, must_be_immutable
class SettingPage extends BaseScaffoldPage<SettingController> {
  @override
  SettingController generateController() {
    return SettingController();
  }

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
      leading:
          Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18.w,
            color: colorScheme.onSurface,
          ).onTab(() {
            Get.back();
          }),
      centerTitle: true,
      title: Text(
        S.of(context!).settings,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
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

  @override
  Widget? getBody() {
    final colorScheme = Theme.of(context!).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 24.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Theme.of(context!).cardColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                Obx(
                  () => _SettingActionTile(
                    icon: Icons.translate_rounded,
                    title: S.of(context!).language,
                    value: controller.currentLanguage.value,
                    onTap: () => Get.toNamed(RouteTable.language),
                  ),
                ),
                Divider(
                  height: 1.h,
                  thickness: 1,
                  indent: 44.w,
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
                Obx(
                  () => _SettingActionTile(
                    icon: Icons.dark_mode_outlined,
                    title: S.of(context!).theme,
                    value: controller.theme.value,
                    onTap: () => Get.toNamed(RouteTable.theme),
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

class _SettingActionTile extends StatelessWidget {
  const _SettingActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 17.w, color: colorScheme.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.58),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.w,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingController extends BaseController {
  final currentLanguage = ''.obs;
  final _storage = Storage();
  static const String _languageKey = 'app_language';
  final themeController = Get.find<ThemeController>();
  final theme = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSavedLanguage();
    _syncThemeDisplay();
  }

  @override
  void onPageActive() {
    super.onPageActive();
    _loadSavedLanguage();
    _syncThemeDisplay();
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

  void _syncThemeDisplay() {
    theme.value = themeController.themeMode.value == ThemeMode.dark
        ? S.current.themeDark
        : themeController.themeMode.value == ThemeMode.light
        ? S.current.themeLight
        : S.current.themeSystem;
  }

  Locale _getLocaleFromString(String languageCode) {
    return Locale(languageCode);
  }
}
