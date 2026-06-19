import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../base/base_controller.dart';
import '../../../base/base_page.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/services/walletconnect_service.dart';
import '../controller/walletconnect_controller.dart';

@GetXRoutePage('/dapp/scan')
class DAppScannerPage extends BasePage<DAppScannerController> {
  @override
  DAppScannerController generateController() => DAppScannerController();

  @override
  Widget buildWidget(DAppScannerController controller) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller.scannerController,
            onDetect: (capture) => controller.onDetect(capture),
          ),
          SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(Get.context!).pop(),
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 24.sp),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(child: Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold))),
                  IconButton(
                    onPressed: () => controller.scannerController.toggleTorch(),
                    icon: Icon(Icons.flash_on, color: Colors.white, size: 24.sp),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 80.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12.r)),
                child: Text('Scan DApp QR code to connect', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DAppScannerController extends BaseController {
  final MobileScannerController scannerController = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  final WalletConnectService _wcService = WalletConnectService.instance;
  bool _isProcessing = false;

  void onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final uri = barcode.rawValue!;

    debugPrint('📱 Detected QR code: ${uri.substring(0, 20)}...');

    if (!uri.startsWith('wc:')) {
      Toast.show('Invalid WalletConnect QR code');
      return;
    }

    _isProcessing = true;

    try {
      await scannerController.stop();
      debugPrint('📷 Scanner stopped');

      Toast.show('Connecting to DApp...');

      // 重要：先创建控制器并等待事件监听器注册完成
      if (!Get.isRegistered<WalletConnectController>()) {
        debugPrint('🎮 Creating permanent WalletConnectController');
        Get.put(WalletConnectController(), permanent: true);
      } else {
        debugPrint('🎮 WalletConnectController already exists');
      }

      // 等待 WalletConnect 初始化和事件监听器注册完成
      debugPrint('⏳ Waiting for WalletConnect initialization and event registration...');
      await Future.delayed(Duration(seconds: 3));

      // 验证控制器已注册
      if (!Get.isRegistered<WalletConnectController>()) {
        throw Exception('WalletConnectController not registered after init');
      }

      // 强制访问控制器以确保 onInit 被调用
      final controller = Get.find<WalletConnectController>();
      debugPrint('✅ Controller verified: ${controller.runtimeType}');

      // 关闭扫码页面
      debugPrint('🔙 Closing scanner page');
      if (Get.context != null) {
        Navigator.of(Get.context!).pop();
      }

      // 等待页面关闭完成
      await Future.delayed(Duration(milliseconds: 500));

      // 在首页触发配对（此时事件监听器已经准备好）
      debugPrint('🔗 Starting pairing on home page...');
      await _wcService.pair(uri);
      debugPrint('✅ Pairing initiated, waiting for proposal event...');

    } catch (e) {
      debugPrint('❌ Pairing failed: $e');
      Toast.show('Connection failed: $e');
      _isProcessing = false;
    }
  }

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }
}
