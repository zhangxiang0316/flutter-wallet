import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

class PicRatioSelectionSheet extends BasePage<PicRatioSelectionController> {
  final String currentMode;
  final Function(String) onSelected;

  PicRatioSelectionSheet({required this.currentMode, required this.onSelected});

  @override
  Widget buildWidget(PicRatioSelectionController controller) {
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
              '选择图片比例',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 20.h),
          _buildOption('16:9 · 横版'),
          SizedBox(height: 16.h),
          _buildOption('9:16 · 竖版'),
          SizedBox(height: 16.h),
          _buildOption('1:1 · 方版'),
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
  PicRatioSelectionController generateController() {
    return PicRatioSelectionController();
  }
}

class PicRatioSelectionController extends BaseController {}
