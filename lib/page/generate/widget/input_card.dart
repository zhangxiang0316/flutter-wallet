import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:omnicast/base/base_page.dart';

import '../../../base/base_controller.dart';
import '../../../utils/global_extension.dart';

class InputCard extends BasePage<InputCardController> {
  @override
  Widget buildWidget(InputCardController controller) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context!).cardColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller.textController,
            maxLines: 4,
            minLines: 4,
            decoration: InputDecoration(
              hintText: '介绍 2025 年 11 月的科技趋势',
              hintStyle: TextStyle(fontSize: 16.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(fontSize: 16.sp, height: 1.5),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              _buildActionIcon(Icons.upload_file_outlined).onTab(() {
                controller.pickFile();
              }),
              SizedBox(width: 20.w),
              _buildActionIcon(Icons.image_outlined).onTab(() {
                controller.pickImage(ImageSource.gallery);
              }),
              SizedBox(width: 20.w),
              _buildActionIcon(Icons.camera_alt_outlined).onTab(() {
                controller.pickImage(ImageSource.camera);
              }),
              const Spacer(),
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: Theme.of(context!).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              ).onTab(() {
                print('------send------');
              }),
            ],
          ),
        ],
      ),
    );
  }

  @override
  InputCardController generateController() {
    return InputCardController();
  }

  Widget _buildActionIcon(IconData icon) {
    return Icon(icon, size: 24.w);
  }
}

class InputCardController extends BaseController {
  TextEditingController textController = TextEditingController();
}
