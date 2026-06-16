import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:reown_walletkit/reown_walletkit.dart';

import '../../../base/base_scaffold_page.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../controller/walletconnect_controller.dart';

/// 已连接 DApp 管理页面
///
/// 显示所有已连接的 DApp 列表，支持断开连接
@GetXRoutePage('/dapp/connected')
class ConnectedDAppsPage extends BaseScaffoldPage<WalletConnectController> {
  const ConnectedDAppsPage({Key? key}) : super(key: key);

  @override
  WalletConnectController generateController() {
    return Get.put(WalletConnectController());
  }

  @override
  PreferredSizeWidget? getAppBar() {
    return AppBar(
      title: Text('Connected DApps'),
      centerTitle: true,
    );
  }

  @override
  Widget? getBody() {
    return Obx(() {
      final sessions = controller.getActiveSessions();

      if (sessions.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _buildDAppCard(context, session);
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 64.sp,
            color: Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            'No connected DApps',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Scan a DApp QR code to connect',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDAppCard(BuildContext context, SessionData session) {
    final theme = Theme.of(context);
    final metadata = session.peer.metadata;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showDAppDetails(context, session),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // DApp 图标
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: metadata.icons.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.network(
                          metadata.icons.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.language,
                            size: 24.sp,
                            color: theme.primaryColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.language,
                        size: 24.sp,
                        color: theme.primaryColor,
                      ),
              ),
              SizedBox(width: 16.w),
              // DApp 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      metadata.url,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 断开按钮
              IconButton(
                onPressed: () => _confirmDisconnect(context, session),
                icon: Icon(
                  Icons.link_off,
                  size: 20.sp,
                  color: Colors.red,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDAppDetails(BuildContext context, SessionData session) {
    final metadata = session.peer.metadata;

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DApp Details',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),
            _buildDetailRow('Name', metadata.name),
            _buildDetailRow('URL', metadata.url),
            _buildDetailRow('Description', metadata.description),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  _confirmDisconnect(context, session);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                icon: Icon(Icons.link_off),
                label: Text('Disconnect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, SessionData session) {
    Get.dialog(
      AlertDialog(
        title: Text('Disconnect DApp?'),
        content: Text(
          'Are you sure you want to disconnect from ${session.peer.metadata.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await controller.disconnectSession(session.topic);
                Toast.show('Disconnected from ${session.peer.metadata.name}');
                controller.update(); // 刷新列表
              } catch (e) {
                Toast.show('Failed to disconnect: $e');
              }
            },
            child: Text(
              'Disconnect',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
