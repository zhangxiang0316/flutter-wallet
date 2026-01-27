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
import '../widget/voice_selection_sheet.dart';

@GetXRoutePage('/text_to_speech')
class TextToSpeechPage extends BaseScaffoldPage<TextToSpeechController> {
  @override
  TextToSpeechController generateController() {
    return TextToSpeechController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.chevron_left, size: 32.w).onTab(() {
        finishActivity();
      }),
      centerTitle: true,
      title: const Text("文本转语音", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputCard(placeholder: '输入文字，上传文件,我们帮你自然的读出来').marginOnly(bottom: 20.h),
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

class TextToSpeechController extends BaseController {
  final selectedOutputLanguage = '中文(普通话)'.obs;
  final selectedVoice = '晓曼'.obs;
}
