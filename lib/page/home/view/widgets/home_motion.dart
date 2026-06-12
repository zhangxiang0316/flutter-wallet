import 'dart:async';

import 'package:flutter/material.dart';

/// 首页通用入场动画。
///
/// 用于卡片、链列表和资产行的轻量淡入/位移动画。组件只在首次插入树时播放，
/// 后续余额刷新不会反复触发，避免资产页阅读时产生干扰。
class HomeEntranceItem extends StatefulWidget {
  const HomeEntranceItem({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.initialOffset = const Offset(0, 0.08),
    this.curve = Curves.easeOutCubic,
  });

  /// 需要播放入场动画的实际内容。
  final Widget child;

  /// 入场延迟，用于首页内容分层出现。
  final Duration delay;

  /// 动画时长。
  final Duration duration;

  /// 初始位移，通常只在 Y 轴上轻微下移。
  final Offset initialOffset;

  /// 动画曲线。
  final Curve curve;

  @override
  State<HomeEntranceItem> createState() => _HomeEntranceItemState();
}

class _HomeEntranceItemState extends State<HomeEntranceItem> {
  /// 当前内容是否已经进入可见状态。
  bool _visible = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    } else {
      _timer = Timer(widget.delay, _show);
    }
  }

  /// 触发入场动画。
  void _show() {
    if (!mounted || _visible) {
      return;
    }
    setState(() {
      _visible = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : widget.initialOffset,
      duration: widget.duration,
      curve: widget.curve,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
