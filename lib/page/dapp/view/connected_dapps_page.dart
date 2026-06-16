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
        itemBuilder: (context, index) => _buildDAppCard(context, sessions[index]),
      );
    });
  }

  Widget _buildDAppCard(BuildContext context, dynamic session) {
    final theme = Theme.of(context);

    // 从 SessionData 获取信息
    final metadata = session.peer.metadata;
    final name = metadata.name;
    final url = metadata.url;
    final topic = session.topic;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.language, color: theme.primaryColor, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4.h),
                      Text(url, style: TextStyle(fontSize: 12.sp, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: Text('Topic: ${topic.substring(0, 16)}...',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontFamily: 'monospace')),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDisconnect(context, topic, name),
                  icon: Icon(Icons.link_off, size: 18.sp, color: Colors.red),
                  label: Text('Disconnect', style: TextStyle(color: Colors.red, fontSize: 13.sp)),
                  style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8.w)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, String topic, String name) {
    Get.dialog(
      AlertDialog(
        title: Text('Disconnect DApp?'),
        content: Text('Disconnect from $name?\n\nYou will need to scan the QR code again to reconnect.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await controller.disconnectSession(topic);
                Toast.show('Disconnected from $name');
              } catch (e) {
                Toast.show('Failed to disconnect: $e');
              }
            },
            child: Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
