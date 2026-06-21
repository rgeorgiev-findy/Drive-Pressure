import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The DrivePressure tire mark: gauge arc + treaded tire + cyan rim.
class TireLogo extends StatelessWidget {
  final double size;
  const TireLogo({super.key, this.size = 116});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _TireLogoPainter()));
  }
}

class _TireLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width / 116;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..color = const Color(0xFF13283A);
    canvas.drawCircle(c, 50 * s, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.cyan;
    canvas.drawArc(Rect.fromCircle(center: c, radius: 50 * s), 135 * pi / 180, 270 * pi / 180, false, arc);

    final tire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11 * s
      ..color = const Color(0xFFDBEEF6);
    canvas.drawCircle(c, 35 * s, tire);

    // tread grooves: dark dashes over the light ring
    final tread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11 * s
      ..color = const Color(0xFF0A1622);
    const seg = 0.16, gap = 0.42;
    double a = 0;
    while (a < 2 * pi) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 35 * s), a, seg, false, tread);
      a += seg + gap;
    }

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s
      ..color = AppColors.cyan;
    canvas.drawCircle(c, 16 * s, rim);

    canvas.drawCircle(c, 4.5 * s, Paint()..color = AppColors.cyan);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
