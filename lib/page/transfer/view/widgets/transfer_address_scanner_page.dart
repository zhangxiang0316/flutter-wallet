import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../generated/l10n.dart';

/// 转账收款地址扫码页面。
///
/// 页面只负责调用相机扫描二维码并返回原始扫码内容。地址解析和输入框回填由
/// [TransferController] 处理，避免扫码 UI 直接耦合链类型和地址规则。
class TransferAddressScannerPage extends StatefulWidget {
  const TransferAddressScannerPage({super.key});

  @override
  State<TransferAddressScannerPage> createState() =>
      _TransferAddressScannerPageState();
}

class _TransferAddressScannerPageState
    extends State<TransferAddressScannerPage> {
  /// 扫码控制器，只识别二维码，降低误扫普通条形码的概率。
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// 避免同一个二维码连续触发多次 pop。
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          S.of(context).scanRecipientAddress,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, _) {
              final torchAvailable = state.torchState != TorchState.unavailable;
              return IconButton(
                tooltip: S.of(context).scanToggleFlash,
                onPressed: torchAvailable ? _toggleTorch : null,
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                ),
              );
            },
          ),
          IconButton(
            tooltip: S.of(context).scanSwitchCamera,
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            fit: BoxFit.cover,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return _ScannerError(message: S.of(context).scanCameraError);
            },
          ),
          const _ScannerMask(),
          Positioned(
            left: 24.w,
            right: 24.w,
            bottom: 64.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: colorScheme.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      S.of(context).scanRecipientAddressTip,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
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

  /// 处理扫码结果，取第一个非空二维码内容并返回上一页。
  void _handleDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue)?.trim();
      if (value == null || value.isEmpty) continue;
      _handled = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(value);
      return;
    }
  }

  /// 切换闪光灯，忽略相机尚未初始化时的瞬时错误。
  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {}
  }

  /// 切换前后摄像头，忽略不支持切换的设备错误。
  Future<void> _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {}
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}

/// 扫码取景框遮罩。
class _ScannerMask extends StatelessWidget {
  const _ScannerMask();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ScannerMaskPainter()));
  }
}

/// 绘制中间透明取景框和四角边线。
class _ScannerMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanSize = size.width * 0.68;
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanSize,
      height: scanSize,
    );
    final outerPath = Path()..addRect(Offset.zero & size);
    final scanPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(18)));
    final maskPath = Path.combine(
      PathOperation.difference,
      outerPath,
      scanPath,
    );
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.48),
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const cornerLength = 34.0;
    final radius = Radius.circular(18.r);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, radius),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _drawCorner(
      canvas,
      borderPaint,
      scanRect.topLeft,
      cornerLength,
      true,
      true,
    );
    _drawCorner(
      canvas,
      borderPaint,
      scanRect.topRight,
      cornerLength,
      false,
      true,
    );
    _drawCorner(
      canvas,
      borderPaint,
      scanRect.bottomLeft,
      cornerLength,
      true,
      false,
    );
    _drawCorner(
      canvas,
      borderPaint,
      scanRect.bottomRight,
      cornerLength,
      false,
      false,
    );
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset corner,
    double length,
    bool left,
    bool top,
  ) {
    final xDirection = left ? 1.0 : -1.0;
    final yDirection = top ? 1.0 : -1.0;
    canvas.drawLine(corner, corner.translate(length * xDirection, 0), paint);
    canvas.drawLine(corner, corner.translate(0, length * yDirection), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 相机不可用或权限被拒绝时的兜底提示。
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  /// 错误提示文案。
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
