import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/global_extension.dart';
import '../controller/setting_controller.dart';
import 'password_cache_settings_page.dart';

@GetXRoutePage('/setting')
/// 设置首页。
///
/// 当前只承载语言、主题和资产显示三个入口。页面本身不保存设置，
/// 仅负责跳转到具体设置页并展示当前语言/主题摘要。
// ignore: use_key_in_widget_constructors, must_be_immutable
class SettingPage extends BaseScaffoldPage<SettingController> {
  /// 创建设置页控制器。
  @override
  SettingController generateController() {
    return SettingController();
  }

  /// 设置页顶部导航栏。
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

  /// 设置项列表。
  ///
  /// 每个设置项使用统一 tile 样式，点击后进入对应子页面。
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
                Divider(
                  height: 1.h,
                  thickness: 1,
                  indent: 44.w,
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
                _SettingActionTile(
                  icon: Icons.security,
                  title: S.of(context!).securitySettings,
                  value: '',
                  onTap: () async {
                    await Get.to(() => const PasswordCacheSettingsPage());
                    controller.update();
                  },
                ),
                Divider(
                  height: 1.h,
                  thickness: 1,
                  indent: 44.w,
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
                _SettingActionTile(
                  icon: Icons.contacts_rounded,
                  title: S.of(context!).addressBook,
                  value: '',
                  onTap: () async {
                    await Get.toNamed(RouteTable.addressBook);
                    controller.update();
                  },
                ),
                Divider(
                  height: 1.h,
                  thickness: 1,
                  indent: 44.w,
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
                _SettingActionTile(
                  icon: Icons.visibility_outlined,
                  title: S.of(context!).assetVisibility,
                  value: '',
                  onTap: () async {
                    await Get.toNamed(RouteTable.assetVisibility);
                    controller.update();
                  },
                ),
                Divider(
                  height: 1.h,
                  thickness: 1,
                  indent: 44.w,
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
                _SettingActionTile(
                  icon: Icons.hub_outlined,
                  title: S.of(context!).networkManagement,
                  value: '',
                  onTap: () async {
                    await Get.toNamed(RouteTable.networkManagement);
                    controller.update();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置页中的单个入口行。
class _SettingActionTile extends StatelessWidget {
  const _SettingActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  /// 设置项左侧图标。
  final IconData icon;

  /// 设置项标题。
  final String title;

  /// 右侧摘要值，例如当前语言或主题。
  final String value;

  /// 点击设置项后的动作。
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
