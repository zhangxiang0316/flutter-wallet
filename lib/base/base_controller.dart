import 'package:get/get.dart';

import 'page_life_state.dart';

/// 基础控制器类，集成 GetX 的 SuperController 并支持页面生命周期状态
class BaseController extends SuperController with PageLifeState {
  @override
  void onDetached() {
    // 应用程序处于分离状态
  }

  @override
  void onHidden() {
    // 应用程序被隐藏
  }

  @override
  void onInactive() {
    // 应用程序处于非活动状态
  }

  @override
  void onPaused() {
    // 应用程序处于暂停状态
  }

  @override
  void onResumed() {
    // 应用程序恢复运行
  }
}
