import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../generated/l10n.dart';
import '../../../wallet/models/wallet_chain.dart';
import '../controller/transfer_controller.dart';
import 'widgets/transfer_fee_panel.dart';
import 'widgets/transfer_form_panel.dart';
import 'widgets/transfer_hero.dart';
import 'widgets/transfer_submitted_panel.dart';
import 'widgets/transfer_unavailable_panel.dart';

// ignore: use_key_in_widget_constructors, must_be_immutable
class TransferPage extends BaseScaffoldPage<TransferController> {
  @override
  TransferController generateController() {
    return TransferController();
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(title: Text(S.of(context!).transfer));
  }

  @override
  Widget? getBody() {
    final args = controller.arguments;
    if (args == null) {
      return const TransferUnavailablePanel();
    }

    final asset = args.asset;
    if (asset.chain == WalletChain.solana) {
      return const TransferUnavailablePanel();
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransferHero(asset: asset),
          SizedBox(height: 16.h),
          TransferFormPanel(asset: asset, controller: controller),
          SizedBox(height: 16.h),
          TransferFeePanel(asset: asset, controller: controller),
          if (controller.transactionHash.isNotEmpty) ...[
            SizedBox(height: 16.h),
            TransferSubmittedPanel(controller: controller),
          ],
        ],
      ),
    );
  }
}
