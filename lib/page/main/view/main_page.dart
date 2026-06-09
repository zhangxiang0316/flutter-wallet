import 'package:flutter/material.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

import '../../home/view/home_page.dart';

/// 主页面
@GetXRoutePage('/main')
// ignore: use_key_in_widget_constructors, must_be_immutable
class MainPage extends BasePage<MainController> {
  @override
  Widget buildWidget(MainController controller) {
    return HomePage();
  }

  @override
  MainController generateController() {
    return MainController();
  }
}

class MainController extends BaseController {}
