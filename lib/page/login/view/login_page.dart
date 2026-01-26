import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';

@GetXRoutePage('/login')
class LoginPage extends BaseScaffoldPage<LoginController> {
  @override
  LoginController generateController() {
    return LoginController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      title: Text('登录', style: TextStyle(fontWeight: FontWeight.w700)),
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => back(),
      ),
      centerTitle: true,
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Text('登录页面'),
    );
  }
}

class LoginController extends BaseController {}
