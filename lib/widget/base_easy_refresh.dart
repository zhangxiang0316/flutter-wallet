import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BaseEasyRefresh extends StatelessWidget {
  final Widget? child;
  final FutureOr Function()? onRefresh;
  final FutureOr Function()? onLoad;
  final EasyRefreshController? controller;
  final bool refreshOnStart;

  const BaseEasyRefresh({
    super.key,
    required this.child,
    this.onRefresh,
    this.onLoad,
    this.controller,
    this.refreshOnStart = false,
  });

  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
      controller: controller,
      refreshOnStart: refreshOnStart,
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

/// 封装了分页逻辑的刷新列表组件
/// 支持通过 [itemBuilder] 构建简单列表，或通过 [contentBuilder] 构建复杂布局
class BaseRefreshView<T> extends StatefulWidget {
  final Future<List<T>> Function(int page, int pageSize) request;
  final Widget Function(BuildContext context, int index, T item)? itemBuilder;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final Widget Function(BuildContext context, List<T> data)? contentBuilder;
  final int pageSize;
  final Widget? emptyWidget;
  final EdgeInsetsGeometry? padding;
  final bool refreshOnStart;

  const BaseRefreshView({
    Key? key,
    required this.request,
    this.itemBuilder,
    this.separatorBuilder,
    this.contentBuilder,
    this.pageSize = 10,
    this.emptyWidget,
    this.padding,
    this.refreshOnStart = true,
  }) : assert(
         itemBuilder != null || contentBuilder != null,
         '必须提供 itemBuilder 或 contentBuilder 之一',
       ),
       super(key: key);

  @override
  State<BaseRefreshView<T>> createState() => _BaseRefreshViewState<T>();
}

class _BaseRefreshViewState<T> extends State<BaseRefreshView<T>> {
  late EasyRefreshController _controller;
  final List<T> _dataList = [];
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    if (widget.refreshOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refresh();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      _page = 1;
      final list = await widget.request(_page, widget.pageSize);
      setState(() {
        _dataList.clear();
        _dataList.addAll(list);
      });
      _controller.finishRefresh();
      _controller.resetFooter();
      if (list.length < widget.pageSize) {
        _controller.finishLoad(IndicatorResult.noMore);
      }
    } catch (e) {
      _controller.finishRefresh(IndicatorResult.fail);
    }
  }

  Future<void> _load() async {
    try {
      _page++;
      final list = await widget.request(_page, widget.pageSize);
      if (mounted) {
        setState(() {
          _dataList.addAll(list);
        });
        if (list.length < widget.pageSize) {
          _controller.finishLoad(IndicatorResult.noMore);
        } else {
          _controller.finishLoad(IndicatorResult.success);
        }
      }
    } catch (e) {
      _page--;
      _controller.finishLoad(IndicatorResult.fail);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_dataList.isEmpty) {
      content = widget.emptyWidget ?? const Center(child: Text("暂无数据"));
    } else if (widget.contentBuilder != null) {
      content = widget.contentBuilder!(context, _dataList);
    } else {
      content = ListView.separated(
        padding: widget.padding ?? EdgeInsets.zero,
        itemBuilder: (ctx, index) =>
            widget.itemBuilder!(ctx, index, _dataList[index]),
        separatorBuilder:
            widget.separatorBuilder ??
            (ctx, index) => const SizedBox(height: 0),
        itemCount: _dataList.length,
      );
    }

    return BaseEasyRefresh(
      controller: _controller,
      refreshOnStart: false,
      onRefresh: _refresh,
      onLoad: _load,
      child: content,
    );
  }
}
