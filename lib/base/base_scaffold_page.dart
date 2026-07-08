import 'package:flutter/material.dart';

import 'base_controller.dart';
import 'base_page.dart';

/// 带有 Scaffold 结构的基类页面，简化了包含 AppBar 和 Body 的页面创建
abstract class BaseScaffoldPage<T extends BaseController> extends BasePage<T> {
  const BaseScaffoldPage({super.key});

  @override
  Widget buildWidget(BuildContext context, T controller) {
    // 构建标准的 Scaffold 结构
    return Scaffold(
      appBar: getAppBar(context),
      body: getBody(context),
      bottomNavigationBar: getBottomNavigationBar(context),
    );
  }

  /// 获取页面标题栏，子类需实现
  PreferredSizeWidget? getAppBar(BuildContext context);

  /// 获取页面主体内容，子类需实现
  Widget? getBody(BuildContext context);

  /// 获取底部导航栏，子类可根据需要重写
  Widget? getBottomNavigationBar(BuildContext context) {
    return null;
  }
}
