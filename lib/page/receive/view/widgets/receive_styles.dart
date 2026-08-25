import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../wallet/models/wallet_chain.dart';
import '../../../../widget/chain_presentation_scope.dart';

/// 收款页通用分隔线颜色。
Color receiveDividerColor(BuildContext context) {
  return Theme.of(context).colorScheme.outline.withValues(alpha: 0.12);
}

/// 获取收款页中每条链的品牌色。
Color receiveChainColor(BuildContext context, WalletChainRef chain) {
  final presentation = ChainPresentationScope.of(context).presentation(chain);
  return Color(presentation.colorValue);
}

/// 获取链在小圆点中的单字母缩写。
String receiveChainLabel(BuildContext context, WalletChainRef chain) {
  return ChainPresentationScope.of(context).presentation(chain).label;
}

/// 收款页通用面板容器。
///
/// 统一白底、圆角、细边框和标题布局。
class ReceivePanel extends StatelessWidget {
  const ReceivePanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  /// 面板标题。
  final String title;

  /// 面板主体内容。
  final Widget child;

  /// 标题右侧的可选附加组件，例如加载状态。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: receiveDividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

/// 币种头像。
///
/// 使用币种首字母和链色生成轻量标识，避免依赖远程图标。
class ReceiveAssetAvatar extends StatelessWidget {
  const ReceiveAssetAvatar({
    super.key,
    required this.symbol,
    required this.color,
    required this.size,
  });

  /// 币种简称。
  final String symbol;

  /// 头像主色。
  final Color color;

  /// 头像尺寸。
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = symbol.trim().isEmpty ? '?' : symbol.characters.first;
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: (size * 0.42).sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 链选择器中的圆点标识。
class ReceiveChainDot extends StatelessWidget {
  const ReceiveChainDot({
    super.key,
    required this.chain,
    required this.selected,
  });

  /// 对应链。
  final WalletChainRef chain;

  /// 是否为当前选中链。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = receiveChainColor(context, chain);
    return Container(
      width: 18.w,
      height: 18.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.18 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        receiveChainLabel(context, chain),
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
