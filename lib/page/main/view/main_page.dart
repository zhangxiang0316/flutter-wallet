import 'package:flutter/material.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

import '../../home/view/home_page.dart';

/// 应用主入口页面。
///
/// 当前底部导航还未拆分多 Tab，主路由直接承载 [HomePage]。保留该层便于后续
/// 扩展交易记录、设置等主导航页面。
@GetXRoutePage('/main')
// ignore: use_key_in_widget_constructors, must_be_immutable
class MainPage extends BasePage<MainController> {
  /// 构建当前主页面内容。
  @override
  Widget buildWidget(BuildContext context, MainController controller) {
    return HomePage();
  }

  /// 创建主页面控制器。
  @override
  MainController generateController() {
    return MainController();
  }
}

/// 主页面控制器。
///
/// 目前没有独立业务状态，只作为主路由的 GetX 控制器占位。
class MainController extends BaseController {}
