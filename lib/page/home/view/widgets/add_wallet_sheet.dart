import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'wallet_sheet_styles.dart';

/// 首页“添加钱包”底部操作面板。
///
/// 这里只负责展示创建/导入两个入口；真正的创建、导入流程由父页面传入的
/// 回调继续打开对应表单，避免多个 BottomSheet 同时叠在一起。
class AddWalletSheet extends StatelessWidget {
  const AddWalletSheet({
    super.key,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  /// 点击“创建钱包”后的后续流程入口。
  final VoidCallback onCreateWallet;

  /// 点击“导入钱包”后的后续流程入口。
  final VoidCallback onImportWallet;

  @override
  Widget build(BuildContext context) {
    return VantSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VantSheetTitle(title: S.of(context).addWallet),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: vantFilledButtonStyle(context),
              onPressed: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onCreateWallet();
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(S.of(context).createWallet),
            ),
          ).marginOnly(bottom: 10.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: vantOutlinedButtonStyle(context),
              onPressed: () {
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onImportWallet();
                });
              },
              icon: const Icon(Icons.file_download_outlined),
              label: Text(S.of(context).importWallet),
            ),
          ),
        ],
      ),
    );
  }
}
