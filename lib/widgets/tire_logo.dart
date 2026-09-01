import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// FindyTPMS logo — treaded tire with signal-wave broadcast arcs.
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
    final c  = Offset(size.width / 2, size.height / 2);
    final s  = size.width / 116;
    const orange = AppColors.orange;

    // Clip to canvas so signal arcs don't overflow
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // ── Tire wall ────────────────────────────────────────────────────────
    final tireWall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 * s
      ..color = const Color(0xFFD0E4EE);
    canvas.drawCircle(c, 29 * s, tireWall);

    // Tread grooves — dark dashes over the light ring
    final tread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12 * s
      ..color = const Color(0xFF080C10);
    const seg = 0.19, gap = 0.43;
    double a = 0;
    while (a < 2 * pi) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 29 * s), a, seg, false, tread);
      a += seg + gap;
    }

    // Subtle tyre side wall accent ring (just inside the tread)
    final sideWall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s
      ..color = orange.withOpacity(0.18);
    canvas.drawCircle(c, 21.5 * s, sideWall);

    // ── Rim & hub ────────────────────────────────────────────────────────
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * s
      ..color = orange;
    canvas.drawCircle(c, 13 * s, rim);

    // 3 spokes
    final spoke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..color = orange.withOpacity(0.55);
    for (var i = 0; i < 3; i++) {
      final angle = pi / 6 + i * 2 * pi / 3;
      canvas.drawLine(
        Offset(c.dx + cos(angle) * 4.5 * s, c.dy + sin(angle) * 4.5 * s),
        Offset(c.dx + cos(angle) * 11.5 * s, c.dy + sin(angle) * 11.5 * s),
        spoke,
      );
    }

    // Hub dot
    canvas.drawCircle(c, 4 * s, Paint()..color = orange);

    // ── Signal waves — right side broadcast arcs ─────────────────────────
    // From about 1 o'clock clockwise to 5 o'clock (the right hemisphere)
    const waveStart = -pi * 0.33;  // ~59° above 3 o'clock ≈ 1 o'clock
    const waveSweep =  pi * 0.66;  // 119° sweep → ends at ~5 o'clock

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 42 * s), waveStart, waveSweep, false,
      Paint()..style = PaintingStyle.stroke
             ..strokeWidth = 2.5 * s
             ..strokeCap = StrokeCap.round
             ..color = orange,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 52 * s), waveStart, waveSweep, false,
      Paint()..style = PaintingStyle.stroke
             ..strokeWidth = 2.0 * s
             ..strokeCap = StrokeCap.round
             ..color = orange.withOpacity(0.55),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 62 * s), waveStart, waveSweep, false,
      Paint()..style = PaintingStyle.stroke
             ..strokeWidth = 1.5 * s
             ..strokeCap = StrokeCap.round
             ..color = orange.withOpacity(0.25),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
