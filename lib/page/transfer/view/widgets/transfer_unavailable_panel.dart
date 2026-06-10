import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'transfer_styles.dart';

/// 转账参数不可用时的兜底提示面板。
///
/// 通常出现在用户直接打开转账路由但没有传入资产参数的场景。
class TransferUnavailablePanel extends StatelessWidget {
  const TransferUnavailablePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.all(18.w),
        decoration: transferPanelDecoration(context),
        child: Text(
          S.of(context).transferUnavailable,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
