import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A 270° telemetry gauge (gap at the bottom). [fraction] is 0..1.
class GaugeRing extends StatelessWidget {
  final double size;
  final double fraction;
  final Color color;
  final double stroke;
  final Widget? child;
  const GaugeRing({
    super.key,
    required this.size,
    required this.fraction,
    this.color = AppColors.cyan,
    this.stroke = 6,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(fraction: fraction.clamp(0, 1), color: color, stroke: stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final double stroke;
  _GaugePainter({required this.fraction, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    const start = 135 * pi / 180;
    const total = 270 * pi / 180;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF18242F);
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, start, total, false, track);
    canvas.drawArc(rect, start, total * fraction, false, value);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter o) =>
      o.fraction != fraction || o.color != color || o.stroke != stroke;
}
