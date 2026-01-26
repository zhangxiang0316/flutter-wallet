import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../utils/global_extension.dart';

@GetXRoutePage('/generate_video')
class GenerateVideoPage extends BaseScaffoldPage<GenerateVideoController> {
  @override
  GenerateVideoController generateController() {
    return GenerateVideoController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.chevron_left, size: 32.w).onTab(() {
        back();
      }),
      centerTitle: true,
      title: const Text("解说视频", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

        ],
      ),
    );
  }
}

class GenerateVideoController extends BaseController {}
