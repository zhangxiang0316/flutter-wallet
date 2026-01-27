import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

class VoiceSelectionSheet extends BasePage<VoiceSelectionController> {
  final String currentMode;
  final Function(String) onSelected;

  VoiceSelectionSheet({required this.currentMode, required this.onSelected});

  @override
  Widget buildWidget(VoiceSelectionController controller) {
    return Container(
      width: double.infinity,
      height: 500.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15.r),
          topRight: Radius.circular(15.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '音色',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 20.h),
          Obx(
            () => Column(
              children: controller.voices
                  .map((voice) => _buildOption(voice).marginOnly(bottom: 16.h))
                  .toList(),
            ),
          ),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _buildOption(String text) {
    final isSelected = text == currentMode;
    return GestureDetector(
      onTap: () {
        onSelected(text);
        back();
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (isSelected) Icon(CupertinoIcons.check_mark, size: 20.r),
        ],
      ),
    );
  }

  @override
  VoiceSelectionController generateController() {
    return VoiceSelectionController();
  }
}

class VoiceSelectionController extends BaseController {
  final voices = [].obs;

  @override
  void onReady() {
    super.onReady();
    // 初始化音色列表
    voices.value = ['小曼', '晓曼', '苏哲', '原野'];
  }
}
