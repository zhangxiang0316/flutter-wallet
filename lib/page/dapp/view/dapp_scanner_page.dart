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
    if (!uri.startsWith('wc:')) {
      Toast.show('Invalid WalletConnect QR code');
      return;
    }
    _isProcessing = true;
    try {
      await scannerController.stop();
      Toast.show('Connecting to DApp...');
      Get.put(WalletConnectController());
      await _wcService.pair(uri);
      await Future.delayed(Duration(milliseconds: 500));
      if (Get.context != null) Navigator.of(Get.context!).pop();
    } catch (e) {
      debugPrint('Pairing failed: $e');
      Toast.show('Connection failed');
      await scannerController.start();
      _isProcessing = false;
    }
  }

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }
}
