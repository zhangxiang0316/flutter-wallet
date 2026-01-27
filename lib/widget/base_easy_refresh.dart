import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BaseEasyRefresh extends StatelessWidget {
  final Widget? child;
  final FutureOr Function()? onRefresh;
  final FutureOr Function()? onLoad;
  final EasyRefreshController? controller;

  const BaseEasyRefresh({
    super.key,
    required this.child,
    this.onRefresh,
    this.onLoad,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
      controller: controller,
      refreshOnStart: false,
      header: CupertinoHeader(
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      footer: CupertinoFooter(
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        emptyWidget: const Text('没有更多数据了', style: TextStyle(fontSize: 14)),
      ),
      onRefresh: onRefresh,
      onLoad: onLoad,
      child: child,
    );
  }
}
