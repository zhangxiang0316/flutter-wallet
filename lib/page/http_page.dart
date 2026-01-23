import 'package:flutter/material.dart';
import 'package:omnicast/utils/global_extension.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import '../base/base_controller.dart';
import '../base/base_scaffold_page.dart';
import '../utils/toast_util.dart';

@GetXRoutePage("/http")
class HttpPage extends BaseScaffoldPage {
  @override
  BaseController generateController() {
    return HttpPageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: const Icon(Icons.arrow_back).onTab(() {
        Get.back();
      }),
      title: const Text("HttpMockPage"),
    );
  }

  @override
  Widget? getBody() {
    return ElevatedButton(
            onPressed: () async {

            },
            child: const Text("click to get Http result"))
        .align(Alignment.center);
  }
}

class HttpPageController extends BaseController {}
