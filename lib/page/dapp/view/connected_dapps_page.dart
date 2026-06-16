import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../utils/toast_util.dart';
import '../controller/walletconnect_controller.dart';

@GetXRoutePage('/dapp/connected')
class ConnectedDAppsPage extends BaseScaffoldPage<WalletConnectController> {
  @override
  WalletConnectController generateController() => Get.put(WalletConnectController());

  @override
  PreferredSizeWidget? getAppBar() => AppBar(title: Text('Connected DApps'), centerTitle: true);

  @override
  Widget? getBody() {
    return Obx(() {
      final sessions = controller.getActiveSessions();
      if (sessions.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off, size: 64.sp, color: Colors.grey),
              SizedBox(height: 16.h),
              Text('No connected DApps', style: TextStyle(fontSize: 16.sp, color: Colors.grey)),
              SizedBox(height: 8.h),
              Text('Scan QR code to connect', style: TextStyle(fontSize: 14.sp, color: Colors.grey[400])),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) => _buildDAppCard(context, sessions[index], index),
      );
    });
  }

  Widget _buildDAppCard(BuildContext context, String sessionId, int index) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Container(
          width: 48.w, height: 48.w,
          decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
          child: Icon(Icons.language, color: theme.primaryColor),
        ),
        title: Text('DApp ${index + 1}', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sessionId, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
        trailing: IconButton(icon: Icon(Icons.link_off, color: Colors.red), onPressed: () => _confirmDisconnect(context, sessionId)),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, String sessionId) {
    Get.dialog(AlertDialog(
      title: Text('Disconnect DApp?'),
      content: Text('Are you sure?'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
        TextButton(
          onPressed: () async {
            Get.back();
            try {
              await controller.disconnectSession(sessionId);
              Toast.show('Disconnected');
              controller.update();
            } catch (e) {
              Toast.show('Failed');
            }
          },
          child: Text('Disconnect', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }
}
