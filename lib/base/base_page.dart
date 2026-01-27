import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:lifecycle/lifecycle.dart';

import '../utils/log_util.dart';
import 'base_controller.dart';

/// 基础页面抽象类，集成 GetView 并支持生命周期管理
abstract class BasePage<T extends BaseController> extends GetView<T> {
  /// 页面 Context
  BuildContext? context;

  /// 抽象方法：由子类实现以生成具体的控制器实例
  T generateController();

  void back() {
    Get.back();
  }

  void finishActivity() {
    Get.back();
  }

  void showActivity(
    String path, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    Get.toNamed(
      path,
      arguments: arguments,
      id: id,
      preventDuplicates: preventDuplicates,
      parameters: parameters,
    );
  }

  @override
  Widget build(BuildContext context) {
    this.context = context;
    // 注入控制器
    Get.put(generateController());
    return LifecycleWrapper(
      onLifecycleEvent: (LifecycleEvent lifecycleEvent) {
        // 监听页面生命周期事件并分发给控制器
        switch (lifecycleEvent) {
          case LifecycleEvent.visible:
            // 页面变为可见
            controller.onPageVisible();
            break;
          case LifecycleEvent.inactive:
            // 页面进入非活动状态
            controller.onPageInActive();
            break;
          case LifecycleEvent.active:
            // 页面进入活动状态
            controller.onPageActive();
            break;
          case LifecycleEvent.invisible:
            // 页面变为不可见
            controller.onPageInVisible();
            break;
          default:
        }
      },
      child: GetBuilder<T>(builder: buildWidget, assignId: true),
    );
  }

  /// 抽象方法：子类实现以构建 UI 界面
  Widget buildWidget(T controller);
}
