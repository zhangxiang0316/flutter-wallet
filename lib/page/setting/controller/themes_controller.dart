import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../base/base_controller.dart';
import '../../../common/theme/app_theme_extension.dart';

/// 主题页控制器。
///
/// 当前只暴露主题扩展对象，便于后续如果页面需要读取品牌色或语义色时复用。
class ThemesController extends BaseController {
  /// 当前上下文中的主题扩展。
  final appTheme = Theme.of(Get.context!).extension<AppThemeExtension>()!;
}
