import 'package:flutter/cupertino.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/preferred_size.dart';
import 'package:omnicast/base/base_scaffold_page.dart';

import '../../../base/base_controller.dart';

class ImageHistoryPage extends BaseScaffoldPage<ImageHistoryController> {
  @override
  ImageHistoryController generateController() {
    return ImageHistoryController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return null;
  }

  @override
  Widget? getBody() {
    return Center(child: Text('图片历史'));
  }
}

class ImageHistoryController extends BaseController {}
