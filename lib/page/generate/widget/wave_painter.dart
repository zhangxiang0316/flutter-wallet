import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double progress;
  final double volume;

  WavePainter({required this.progress, required this.volume});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    _drawWave(
      canvas,
      size,
      centerY,
      Colors.pinkAccent.withOpacity(0.8),
      volume * 12,
      0,
    );

    _drawWave(
      canvas,
      size,
      centerY,
      Colors.lightBlueAccent.withOpacity(0.8),
      volume * 8,
      pi / 2,
    );

    _drawWave(
      canvas,
      size,
      centerY,
      Colors.purpleAccent.withOpacity(0.6),
      volume * 6,
      pi,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    double centerY,
    Color color,
    double amplitude,
    double phaseOffset,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (double x = 0; x <= size.width; x++) {
      final xRatio = x / size.width;
      final normalizedX = xRatio * 2 * pi;

      // ⭐ 关键：两端衰减包络
      // final envelope = sin(pi * xRatio);
      final envelope = pow(sin(pi * xRatio), 3).toDouble();

      final y =
          centerY +
          sin(normalizedX + progress * 2 * pi + phaseOffset) *
              amplitude *
              envelope;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return true;
  }
}
