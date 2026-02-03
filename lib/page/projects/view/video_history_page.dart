import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:omnicast/base/base_scaffold_page.dart';
import 'package:omnicast/widget/base_easy_refresh.dart';

import '../../../base/base_controller.dart';

/// 视频历史页面
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
    return BaseRefreshView<Map<String, dynamic>>(
      request: (page, pageSize) => controller.getHistoryList(page, pageSize),
      contentBuilder: (context, dataList) {
        return SingleChildScrollView(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dataList.length,
            padding: EdgeInsets.only(bottom: 10.h),
            separatorBuilder: (context, index) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final item = dataList[index];
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
              );
            },
          ),
        );
      },
    );
  }
}

class VideoHistoryController extends BaseController {
  /// 获取视频历史列表
  Future<List<Map<String, dynamic>>> getHistoryList(
    int page,
    int pageSize,
  ) async {
    print('------------获取视频历史列表------------$page-----$pageSize');
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 1000));

    // 模拟分页数据
    return List.generate(pageSize, (index) {
      final id = (page - 1) * pageSize + index;
      return {
        'id': id,
        'title': '视频标题 $id',
        'cover': 'https://picsum.photos/100/100?random=$id',
      };
    });
  }
}
