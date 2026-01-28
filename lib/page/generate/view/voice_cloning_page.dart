import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';
import '../../../utils/global_extension.dart';
import '../widget/voice_wave.dart';

@GetXRoutePage('/voice_cloning')
class VoiceCloningPage extends BaseScaffoldPage<VoiceCloningController> {
  @override
  VoiceCloningController generateController() {
    return VoiceCloningController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      leading: Icon(Icons.chevron_left, size: 32.w).onTab(() {
        finishActivity();
      }),
      centerTitle: true,
      title: const Text("音色克隆", style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget? getBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context!).cardColor,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Center(
                  child: Text(
                    "通过对话克隆你的音色",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).marginOnly(bottom: 10.h),
                Center(
                  child: Text("请在安静的环境下对话", style: TextStyle(fontSize: 12.sp)),
                ).marginOnly(bottom: 20.h),
                Obx(() => VoiceWave(volume: controller.volume.value)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("开始对话"),
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

class VoiceCloningController extends BaseController {
  final RxDouble volume = 2.2.obs;

  @override
  void onInit() {
    super.onInit();
    // Timer.periodic(const Duration(milliseconds: 2000), (timer) {
    //   volume.value = Random().nextDouble() * 3;
    //   print(volume.value);
    // });
  }
}
