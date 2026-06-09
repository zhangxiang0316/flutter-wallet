import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../generated/l10n.dart';
import 'wallet_sheet_styles.dart';

class AddWalletSheet extends StatelessWidget {
  const AddWalletSheet({
    super.key,
    required this.onCreateWallet,
    required this.onImportWallet,
  });

  final VoidCallback onCreateWallet;
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
