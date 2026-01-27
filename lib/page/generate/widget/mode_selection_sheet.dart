import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

class ModeSelectionSheet extends BasePage<ModeSelectionController> {
  final String currentMode;
  final Function(String) onSelected;

  ModeSelectionSheet({required this.currentMode, required this.onSelected});

  @override
  Widget buildWidget(ModeSelectionController controller) {
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
              '选择模式',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 20.h),
          _buildOption('知识图解', '生成图解视频'),
          SizedBox(height: 16.h),
          _buildOption('故事演义', '生成儿童故事'),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _buildOption(String text, String desc) {
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
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          if (isSelected) Icon(CupertinoIcons.check_mark, size: 20.r),
        ],
      ),
    );
  }

  @override
  ModeSelectionController generateController() {
    return ModeSelectionController();
  }
}

class ModeSelectionController extends BaseController {}
