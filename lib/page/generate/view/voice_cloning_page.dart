import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../utils/global_extension.dart';

@GetXRoutePage('/voice_cloning')
class VoiceCloningPage extends BaseScaffoldPage<VoiceCloningController> {
  @override
  VoiceCloningController generateController() {
    return VoiceCloningController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.chevron_left, size: 32.w).onTab(() {
        finishActivity();
      }),
      centerTitle: true,
      title: const Text("音色克隆", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('111111111')],
      ),
    );
  }
}

class VoiceCloningController extends BaseController {}
