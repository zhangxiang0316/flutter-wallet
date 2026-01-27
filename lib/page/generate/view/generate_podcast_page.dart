import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';
import 'package:omnicast/page/generate/widget/input_card.dart';
import 'package:omnicast/page/generate/widget/mode_selection_sheet.dart';

import '../../../base/base_controller.dart';
import '../../../utils/global_extension.dart';
import '../../../widget/line_item.dart';
import '../widget/output_language_selection_sheet.dart';
import '../widget/pic_ratio_selection_sheet.dart';
import '../widget/voice_selection_sheet.dart';

/// 生成播客页面
@GetXRoutePage('/generate_podcast')
class GeneratePodcastPage extends BaseScaffoldPage<GeneratePodcastController> {
  @override
  GeneratePodcastController generateController() {
    return GeneratePodcastController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.chevron_left, size: 32.w).onTab(() {
        back();
      }),
      centerTitle: true,
      title: const Text("AI 播客", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputCard(placeholder: '2025 年 11 月的科技趋势').marginOnly(bottom: 20.h),
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
                    title: '模式',
                    value: controller.selectedMode.value,
                    onTap: () {
                      Get.bottomSheet(
                        ModeSelectionSheet(
                          currentMode: controller.selectedMode.value,
                          onSelected: (value) {
                            controller.selectedMode.value = value;
                          },
                        ),
                      );
                    },
                  ),
                ).marginOnly(bottom: 16.h),
                Obx(
                  () => LineItem(
                    title: '输出语言',
                    value: controller.selectedOutputLanguage.value,
                    onTap: () {
                      Get.bottomSheet(
                        OutputLanguageSelectionSheet(
                          currentMode: controller.selectedOutputLanguage.value,
                          onSelected: (value) {
                            controller.selectedOutputLanguage.value = value;
                          },
                        ),
                      );
                    },
                  ),
                ).marginOnly(bottom: 16.h),
                Obx(
                  () => LineItem(
                    title: '音色',
                    value: controller.selectedVoice.value,
                    onTap: () {
                      Get.bottomSheet(
                        VoiceSelectionSheet(
                          currentMode: controller.selectedVoice.value,
                          onSelected: (value) {
                            controller.selectedVoice.value = value;
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

class GeneratePodcastController extends BaseController {
  final TextEditingController textController = TextEditingController();
  final selectedMode = '知识图解'.obs;
  final selectedPicRatio = '16:9 · 横版'.obs;
  final selectedOutputLanguage = '中文(普通话)'.obs;
  final selectedVoice = '晓曼'.obs;

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
}
