import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/event_bus.dart';
import 'page_life_state.dart';

/// 基础控制器类，集成 GetX 的 SuperController 并支持页面生命周期状态
class BaseController extends SuperController with PageLifeState {
  /// EventBus 订阅对象
  StreamSubscription? streamSubscription;

  @mustCallSuper
  @override
  void onReady() {
    super.onReady();
    // 获取需要监听的事件类型列表
    var listenerEventList = getListenEvent();
    // 如果有需要监听的事件，则注册 EventBus 监听
    if (listenerEventList.isNotEmpty) {
      streamSubscription = EventBus()
          .onTypes(listenerEventList)
          .listen(onReceiveEvent);
    }
  }

  /// 接收到 EventBus 事件的回调
  void onReceiveEvent(event) {}

  /// 返回需要监听的事件类型列表，子类可重写此方法
  List<Type> getListenEvent() {
    return [];
  }

  @mustCallSuper
  @override
  void onClose() {
    super.onClose();
    // 取消 EventBus 事件监听
    streamSubscription?.cancel();
  }

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
