import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:getx_route_annotations/getx_route_annotations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../base/base_page.dart';
import '../../../utils/toast_util.dart';
import '../../../wallet/services/walletconnect_service.dart';

/// WalletConnect 扫码页面
///
/// 扫描 DApp 的 WalletConnect 二维码建立连接
@GetXRoutePage('/dapp/scan')
class DAppScannerPage extends BasePage {
  const DAppScannerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _DAppScannerView();
  }
}

class _DAppScannerView extends StatefulWidget {
  @override
  State<_DAppScannerView> createState() => _DAppScannerViewState();
}

class _DAppScannerViewState extends State<_DAppScannerView> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 相机预览
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 扫描框
          _buildScanMask(context),

          // 顶部导航栏
          SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // 标题
                  Expanded(
                    child: Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 手电筒按钮
                  IconButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    icon: ValueListenableBuilder(
                      valueListenable: _scannerController.torchState,
                      builder: (context, state, child) {
                        return Icon(
                          state == TorchState.on
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: Colors.white,
                          size: 24.sp,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部提示
          Positioned(
            left: 0,
            right: 0,
            bottom: 80.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'Scan DApp QR code to connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建扫描框遮罩
  Widget _buildScanMask(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return CustomPaint(
      size: size,
      painter: _ScanMaskPainter(
        scanAreaSize: scanAreaSize,
        borderColor: Theme.of(context).primaryColor,
      ),
    );
  }

  /// 检测到二维码
  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final uri = barcode.rawValue!;

    // 检查是否为 WalletConnect URI
    if (!uri.startsWith('wc:')) {
      Toast.show('Invalid WalletConnect QR code');
      return;
    }

    _isProcessing = true;

    try {
      // 停止扫描
      await _scannerController.stop();

      // 显示连接中提示
      Toast.show('Connecting to DApp...');

      // 调用 WalletConnect 配对
      await WalletConnectService.instance.pair(uri);

      // 返回上一页（连接请求会通过事件流处理）
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('❌ Pairing failed: $e');
      Toast.show('Connection failed: $e');

      // 恢复扫描
      await _scannerController.start();
      _isProcessing = false;
    }
  }
}

/// 扫描框遮罩绘制器
class _ScanMaskPainter extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;

  _ScanMaskPainter({
    required this.scanAreaSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final left = centerX - scanAreaSize / 2;
    final top = centerY - scanAreaSize / 2;

    // 绘制半透明背景
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
          Radius.circular(16.r),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    // 绘制边框
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.w;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
        Radius.circular(16.r),
      ),
      borderPaint,
    );

    // 绘制四角
    final cornerLength = 30.w;
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.w
      ..strokeCap = StrokeCap.round;

    // 左上角
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );

    // 右上角
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );

    // 左下角
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );

    // 右下角
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      Offset(left + scanAreaSize, top + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
