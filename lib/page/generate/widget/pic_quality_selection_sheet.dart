import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

class PicQualitySelectionSheet extends BasePage<PicQualitySelectionController> {
  final String currentMode;
  final Function(String) onSelected;

  PicQualitySelectionSheet({
    required this.currentMode,
    required this.onSelected,
  });

  @override
  Widget buildWidget(PicQualitySelectionController controller) {
    return Container(
      width: double.infinity,
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
              '选择图片清晰度',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 20.h),
          Obx(
            () => Column(
              children: controller.modes
                  .map((e) => _buildOption(e).marginOnly(bottom: 16.h))
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
  PicQualitySelectionController generateController() {
    return PicQualitySelectionController();
  }
}

class PicQualitySelectionController extends BaseController {
  final List<String> modes = ['1K', '2K', '4K'].obs;
}
