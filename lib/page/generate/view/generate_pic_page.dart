import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../utils/global_extension.dart';
import '../../../widget/line_item.dart';
import '../widget/input_card.dart';
import '../widget/output_language_selection_sheet.dart';
import '../widget/pic_ratio_selection_sheet.dart';
import '../widget/voice_selection_sheet.dart';

/// 生成图片页面
@GetXRoutePage('/generate_pic')
class GeneratePicPage extends BaseScaffoldPage<GeneratePicController> {
  @override
  GeneratePicController generateController() {
    return GeneratePicController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.chevron_left, size: 32.w).onTab(() {
        finishActivity();
      }),
      centerTitle: true,
      title: const Text("AI 生图", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputCard(
            placeholder: '描述你想生成的图片',
          ).marginOnly(bottom: 20.h),
          Text(
            '创建设置',
            style: TextStyle(fontSize: 14.sp),
          ).marginOnly(bottom: 16.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context!).cardColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                Obx(
                      () => LineItem(
                    title: '图片比例',
                    value: controller.selectedPicRatio.value,
                    onTap: () {
                      Get.bottomSheet(
                        PicRatioSelectionSheet(
                          currentMode: controller.selectedPicRatio.value,
                          onSelected: (value) {
                            controller.selectedPicRatio.value = value;
                          },
                        ),
                      );
                    },
                  ),
                ).marginOnly(bottom: 16.h),
                Obx(
                  () => LineItem(
                    title: '图片清晰度',
                    value: controller.selectedPicQuality.value,
                    onTap: () {
                      Get.bottomSheet(
                        VoiceSelectionSheet(
                          currentMode: controller.selectedPicQuality.value,
                          onSelected: (value) {
                            controller.selectedPicQuality.value = value;
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GeneratePicController extends BaseController {
  final selectedPicRatio = '1:1'.obs;
  final selectedPicQuality = '2K'.obs;
}
