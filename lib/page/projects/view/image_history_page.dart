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
    return BaseEasyRefresh(
      controller: controller.easyRefreshController,
      onRefresh: () async {
        controller.loadList(true);
      },
      onLoad: () async {
        controller.loadList(false);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Obx(
                () => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.imageHistoryList.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 每行两个
                    crossAxisSpacing: 16, // 横向间距
                    mainAxisSpacing: 16, // 纵向间距
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    var item = controller.imageHistoryList[index];
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
            ),
          );
        },
      ),
    );
  }
}

class ImageHistoryController extends BaseController {
  late EasyRefreshController? easyRefreshController;
  final RxList<dynamic> imageHistoryList = [].obs;

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
      imageHistoryList.clear();
    }
    imageHistoryList.addAll(
      List.generate(
        10,
        (index) => {
          'id': index,
          'title': '图片标题 $index',
          'cover': 'https://picsum.photos/300/200?random=$index',
        },
      ),
    );
    easyRefreshController?.finishRefresh();
    easyRefreshController?.finishLoad();
  }
}
