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
/// 封装分页 + 下拉刷新 + 上拉加载的通用组件
class BaseRefreshView<T> extends StatefulWidget {
  /// 分页请求
  final Future<List<T>> Function(int page, int pageSize) request;

  /// 刷新前钩子（如重置筛选条件）
  final Future<void> Function()? onBeforeRefresh;

  /// item 构建
  final Widget Function(BuildContext context, int index, T item)? itemBuilder;

  /// 分割线
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// 完全自定义内容构建
  final Widget Function(BuildContext context, List<T> data)? contentBuilder;

  /// 错误回调
  final void Function(Object error, bool isRefresh)? onError;

  final int pageSize;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyWidget;
  final bool refreshOnStart;

  const BaseRefreshView({
    super.key,
    required this.request,
    this.onBeforeRefresh,
    this.itemBuilder,
    this.separatorBuilder,
    this.contentBuilder,
    this.onError,
    this.pageSize = 10,
    this.padding,
    this.emptyWidget,
    this.refreshOnStart = true,
  }) : assert(
  itemBuilder != null || contentBuilder != null,
  '必须提供 itemBuilder 或 contentBuilder 之一',
  );

  @override
  State<BaseRefreshView<T>> createState() => _BaseRefreshViewState<T>();
}

class _BaseRefreshViewState<T> extends State<BaseRefreshView<T>> {
  late final EasyRefreshController _controller;

  final List<T> _dataList = [];
  int _page = 1;

  bool _isRefreshing = false;
  bool _isLoading = false;

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

  /// 对外暴露的刷新方法（支持 GlobalKey 调用）
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await widget.onBeforeRefresh?.call();

      _page = 1;
      final list = await widget.request(_page, widget.pageSize);

      if (!mounted) return;

      setState(() {
        _dataList
          ..clear()
          ..addAll(list);
      });

      _controller.finishRefresh();
      _controller.resetFooter();

      if (list.length < widget.pageSize) {
        _controller.finishLoad(IndicatorResult.noMore);
      }
    } catch (e) {
      widget.onError?.call(e, true);
      _controller.finishRefresh(IndicatorResult.fail);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      _page++;
      final list = await widget.request(_page, widget.pageSize);

      if (!mounted) return;

      setState(() {
        _dataList.addAll(list);
      });

      if (list.length < widget.pageSize) {
        _controller.finishLoad(IndicatorResult.noMore);
      } else {
        _controller.finishLoad(IndicatorResult.success);
      }
    } catch (e) {
      _page--;
      widget.onError?.call(e, false);
      _controller.finishLoad(IndicatorResult.fail);
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (_dataList.isEmpty) {
      /// ⚠️ 空态也必须是可滚动的
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding ?? EdgeInsets.zero,
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: widget.emptyWidget ??
                const Center(child: Text('暂无数据')),
          ),
        ],
      );
    } else if (widget.contentBuilder != null) {
      content = widget.contentBuilder!(context, _dataList);
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding ?? EdgeInsets.zero,
        itemCount: _dataList.length,
        itemBuilder: (ctx, index) =>
            widget.itemBuilder!(ctx, index, _dataList[index]),
        separatorBuilder:
        widget.separatorBuilder ??
                (_, __) => const SizedBox(height: 0),
      );
    }

    return BaseEasyRefresh(
      controller: _controller,
      onRefresh: _refresh,
      onLoad: _load,
      child: content,
    );
  }
}
