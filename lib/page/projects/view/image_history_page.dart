import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../widget/base_easy_refresh.dart';

/// 图片历史页面
class ImageHistoryPage extends BaseScaffoldPage<ImageHistoryController> {
  @override
  ImageHistoryController generateController() {
    return ImageHistoryController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return null;
  }

  @override
  Widget? getBody() {
    return BaseRefreshView(
      request: (page, pageSize) => controller.getHistoryList(page, pageSize),
      contentBuilder: (context, dataList) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dataList.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 每行两个
                    crossAxisSpacing: 16, // 横向间距
                    mainAxisSpacing: 16, // 纵向间距
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    var item = dataList[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.all(16.h),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Image.network(
                              item['cover'],
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            item['title'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ImageHistoryController extends BaseController {
  Future<List<Map<String, dynamic>>> getHistoryList(
    int page,
    int pageSize,
  ) async {
    print('------------获取图片历史列表------------$page-----$pageSize');
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
