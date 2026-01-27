import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omnicast/base/base_controller.dart';
import 'package:omnicast/base/base_page.dart';

class OutputLanguageSelectionSheet
    extends BasePage<OutputLanguageSelectionController> {
  final String currentMode;
  final Function(String) onSelected;

  OutputLanguageSelectionSheet({
    required this.currentMode,
    required this.onSelected,
  });

  @override
  Widget buildWidget(OutputLanguageSelectionController controller) {
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
              '选择输出语言',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 20.h),
          _buildOption('英语'),
          SizedBox(height: 16.h),
          _buildOption('中文(普通话)'),
          SizedBox(height: 16.h),
          _buildOption('泰语'),
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
  OutputLanguageSelectionController generateController() {
    return OutputLanguageSelectionController();
  }
}

class OutputLanguageSelectionController extends BaseController {}
