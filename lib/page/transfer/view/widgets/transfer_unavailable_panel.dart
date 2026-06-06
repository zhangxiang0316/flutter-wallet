import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../generated/l10n.dart';
import 'transfer_styles.dart';

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
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
