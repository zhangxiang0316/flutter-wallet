import 'package:flutter/widgets.dart';

import '../wallet/policies/chain_presentation_policy.dart';

/// 向所有路由和弹窗提供应用级共享的链展示策略。
class ChainPresentationScope extends InheritedWidget {
  const ChainPresentationScope({
    super.key,
    required this.policy,
    required super.child,
  });

  final ChainPresentationPolicy policy;

  static ChainPresentationPolicy of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ChainPresentationScope>();
    assert(scope != null, 'ChainPresentationScope is missing above this UI.');
    return scope!.policy;
  }

  @override
  bool updateShouldNotify(ChainPresentationScope oldWidget) {
    return !identical(policy, oldWidget.policy);
  }
}
