import 'package:flutter/cupertino.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_controller.dart';

import '../base/base_scaffold_page.dart';

@GetXRoutePage("/demo")
class DemoPage extends BaseScaffoldPage<DemoPageController> {
  @override
  DemoPageController generateController() {
    return DemoPageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return null;
  }

  @override
  Widget? getBody() {
    return const Text("Demo Page");
  }
}

class DemoPageController extends BaseController {}
