import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:omnicast/base/base_page.dart';

import '../base/base_controller.dart';

/// 列表项
class LineItem extends BasePage<LineController> {
  final String title;
  final String value;
  final VoidCallback? onTap;

  LineItem({required this.title, required this.value, this.onTap});

  @override
  Widget buildWidget(LineController controller) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 12.5.sp),
          ).marginOnly(right: 10.w),
          Icon(Icons.arrow_forward_ios, size: 16.r),
        ],
      ),
    );
  }

  @override
  LineController generateController() {
    return LineController();
  }
}

class LineController extends BaseController {}
