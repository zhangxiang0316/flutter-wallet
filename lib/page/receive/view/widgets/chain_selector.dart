import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import '../../../../wallet/models/wallet_chain.dart';
import 'receive_styles.dart';

/// 链选择器。
///
/// 横向展示所有支持链，切换后控制器会同步币种列表和地址。
class ReceiveChainSelector extends StatelessWidget {
  const ReceiveChainSelector({
    super.key,
    required this.selectedChain,
    required this.onSelected,
  });

  /// 当前选中的链。
  final WalletChain selectedChain;

  /// 用户选择链后的回调。
  final ValueChanged<WalletChain> onSelected;

  @override
  Widget build(BuildContext context) {
    return ReceivePanel(
      title: S.of(context).selectReceiveChain,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: WalletChain.values
              .map((chain) {
                final selected = chain == selectedChain;
                final color = receiveChainColor(chain);
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    labelPadding: EdgeInsets.symmetric(horizontal: 8.w),
                    avatar: ReceiveChainDot(chain: chain, selected: selected),
                    label: Text(
                      chain.name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? color
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    selectedColor: color.withValues(alpha: 0.12),
                    backgroundColor: Theme.of(context).cardColor,
                    side: BorderSide(
                      color: selected
                          ? color.withValues(alpha: 0.42)
                          : receiveDividerColor(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    onSelected: (_) => onSelected(chain),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}
