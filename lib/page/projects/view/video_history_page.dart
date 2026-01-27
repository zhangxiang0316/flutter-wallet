import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:omnicast/base/base_scaffold_page.dart';
import 'package:omnicast/widget/base_easy_refresh.dart';

import '../../../base/base_controller.dart';

class VideoHistoryPage extends BaseScaffoldPage<VideoHistoryController> {
  @override
  VideoHistoryController generateController() {
    return VideoHistoryController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return null;
  }

  @override
  Widget? getBody() {
    return BaseEasyRefresh(
      controller: controller.easyRefreshController,
      onRefresh: () async {
        controller.loadList(true);
      },
      onLoad: () async {
        controller.loadList(false);
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 16.h),
        child: Obx(
          () => Column(
            children: controller.videoHistoryList
                .map(
                  (item) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context!).cardColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.all(16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.network(
                              item['cover'],
                              width: 100,
                              height: 100,
                            ).marginOnly(right: 10.w),
                            Text(item['title']),
                          ],
                        ),
                      ],
                    ),
                  ).marginOnly(bottom: 10.h),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class VideoHistoryController extends BaseController {
  late EasyRefreshController? easyRefreshController;
  final RxList<dynamic> videoHistoryList = [].obs;

  @override
  void onInit() {
    super.onInit();
    easyRefreshController = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    loadList(true);
  }

  void loadList(bool isRefresh) async {
    if (isRefresh) {
      videoHistoryList.clear();
    }
    videoHistoryList.addAll(
      List.generate(
        4,
        (index) => {
          'id': index,
          'title': '视频标题 $index',
          'cover': 'https://picsum.photos/100/100?random=$index',
        },
      ),
    );
    easyRefreshController?.finishRefresh();
    easyRefreshController?.finishLoad();
  }
}
