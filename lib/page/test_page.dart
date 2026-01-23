import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../utils/global_extension.dart';

@GetXRoutePage("/test")
class TestPage extends BaseScaffoldPage<TestPageController> {
  @override
  generateController() {
    return TestPageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: const Icon(Icons.arrow_back).onTab(() {
        Get.back();
      }),
      title: const Text("LightStorage"),
    );
  }

  @override
  Widget? getBody() {
    return Column(
      children: [
        Text('${controller.id}', style: TextStyle(color: Colors.black)),
      ],
    );
  }
}

class TestPageController extends BaseController {
  int id = 0;
  String name = '';

  @override
  void onPageVisible() {
    // TODO: implement onPageVisible
    super.onPageVisible();
    final args = Get.arguments;

    id = args['id'];
    name = args['name'];
    update();
  }
}
