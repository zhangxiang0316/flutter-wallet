import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/page/projects/view/image_history_page.dart';
import 'package:omnicast/page/projects/view/video_history_page.dart';
import 'package:omnicast/utils/global_extension.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_scaffold_page.dart';

/// 项目页面
@GetXRoutePage('/projects')
class ProjectsPage extends BaseScaffoldPage<ProjectsController> {
  @override
  ProjectsController generateController() {
    return ProjectsController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(title: Text('项目'));
  }

  @override
  Widget? getBody() {
    return Container(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context!).cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Center(
                    child: Text(
                      '音频和视频',
                      style: TextStyle(
                        color: controller.bottomSelectedIndex == 0
                            ? Theme.of(context!).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ),
                ).onTab(() => controller.bottomTap(0)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context!).cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Center(
                    child: Text(
                      'AI 生图',
                      style: TextStyle(
                        color: controller.bottomSelectedIndex == 1
                            ? Theme.of(context!).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  ),
                ).onTab(() => controller.bottomTap(1)),
              ),
            ],
          ).marginOnly(bottom: 16.h),
          Expanded(child: buildPageView()),
        ],
      ),
    );
  }

  Widget buildPageView() {
    return PageView(
      physics: const NeverScrollableScrollPhysics(), // 禁止滑动
      controller: controller.pageController,
      onPageChanged: controller.pageChanged,
      children: [VideoHistoryPage(), ImageHistoryPage()],
    );
  }
}

class ProjectsController extends BaseController {
  int bottomSelectedIndex = 0;
  PageController? pageController;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: bottomSelectedIndex);
  }

  void bottomTap(int index) {
    bottomSelectedIndex = index;
    pageController?.jumpToPage(index);
    update();
  }

  void pageChanged(int index) {
    bottomSelectedIndex = index;
    update();
  }
}
