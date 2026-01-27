import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';
import '../../../events/text_event.dart';
import '../../../generated/l10n.dart';
import '../../../generated/route_table.dart';
import '../../../utils/storage.dart';
import '../../../utils/toast_util.dart';

@GetXRoutePage('/home')
class HomePage extends BaseScaffoldPage<HomePageController> {
  @override
  HomePageController generateController() {
    return HomePageController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      title: Text(S.of(context!).appName),
      actions: [
        IconButton(
          icon: Icon(CupertinoIcons.gear_big, size: 25.w),
          onPressed: () {
            // 处理设置按钮点击事件
            Get.toNamed(RouteTable.setting);
          },
        ),
      ],
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40.h),
          Row(
            children: [
              Icon(CupertinoIcons.flag, size: 40.h).marginOnly(right: 5.w),
              Text(
                S.of(context!).hello,
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ).marginOnly(bottom: 10.h),
          Text(
            S.of(context!).whatToCreate,
            style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w700),
          ).marginOnly(bottom: 60.h),

          Row(
            children: [
              buildItem(
                S.of(context!).explanationVideo,
                CupertinoIcons.play_circle,
                RouteTable.generate_video,
              ),
              const SizedBox(width: 12),
              buildItem(S.of(context!).ppt, CupertinoIcons.plus, RouteTable.generate_ppt),
            ],
          ).marginOnly(bottom: 12.h),
          Row(
            children: [
              buildItem(
                S.of(context!).aiBlog,
                CupertinoIcons.play_circle,
                RouteTable.generate_podcast,
              ),
              const SizedBox(width: 12),
              buildItem(
                S.of(context!).textToSpeech,
                CupertinoIcons.plus,
                RouteTable.text_to_speech,
              ),
            ],
          ).marginOnly(bottom: 12.h),

          Row(
            children: [
              buildItem(
                S.of(context!).aiImage,
                CupertinoIcons.play_circle,
                RouteTable.generate_pic,
              ),
              const SizedBox(width: 12),
              buildItem(S.of(context!).voiceCloning, CupertinoIcons.plus, RouteTable.voice_cloning),
            ],
          ).marginOnly(bottom: 12.h),
        ],
      ),
    );
  }

  /// 构建首页功能项
  /// [title] 功能项标题
  /// [icon] 功能项图标
  Widget buildItem(String title, IconData icon, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // if (!controller.isLogin) {
          //   Get.toNamed(RouteTable.login);
          //   return;
          // }
          showActivity(route);
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Theme.of(context!).cardColor,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30.h).marginOnly(bottom: 5.h),
              Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePageController extends BaseController {
  String token = '';
  bool isLogin = false;

  @override
  void onPageActive() async {
    super.onPageActive();
    token = await Storage().getStorage('token');
    isLogin = token.isNotEmpty;
  }

  @override
  void onReceiveEvent(event) {
    print("---1111111----${event.text}");
    switch (event.runtimeType) {
      case CustomTextEvent:
        Toast.show(event.text);
        break;
      default:
    }
  }
}
