import 'dart:math';
import 'package:flutter/material.dart';

/// Small filled-area line chart for the pressure trend.
class MiniTrend extends StatelessWidget {
  final Color color;
  final List<double> data;
  final double height;
  const MiniTrend({super.key, required this.color, required this.data, this.height = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TrendPainter(color, data)),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final Color color;
  final List<double> d;
  _TrendPainter(this.color, this.d);

  @override
  void paint(Canvas canvas, Size size) {
    if (d.length < 2) return;
    final maxV = d.reduce(max);
    final minV = d.reduce(min);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    Offset pt(int i) {
      final x = size.width * i / (d.length - 1);
      final y = size.height - ((d[i] - minV) / range) * size.height * 0.8 - size.height * 0.1;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < d.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.35), color.withOpacity(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) => o.color != color || o.d != d;
}
