import 'package:flutter/material.dart';
import 'package:omnicast/page/generate/widget/wave_painter.dart';

class VoiceWave extends StatefulWidget {
  final double volume;

  const VoiceWave({super.key, required this.volume});

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          size: const Size(double.infinity, 80),
          painter: WavePainter(
            progress: _controller.value,
            volume: widget.volume,
          ),
        );
      },
    );
  }
}
