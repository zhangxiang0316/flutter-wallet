import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../base/base_controller.dart';

@GetXRoutePage('/dapp/connected')
class ConnectedDAppsPage extends BaseScaffoldPage<ConnectedDAppsController> {
  ConnectedDAppsPage({Key? key}) : super(key: key);

  @override
  ConnectedDAppsController generateController() => Get.put(ConnectedDAppsController());

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(title: Text('Connected DApps'), centerTitle: true);
  }

  @override
  Widget? getBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off, size: 64.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          Text('No connected DApps', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
          SizedBox(height: 8.h),
          Text('Feature coming soon', style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
        ],
      ),
    );
  }
}

class ConnectedDAppsController extends BaseController {}
