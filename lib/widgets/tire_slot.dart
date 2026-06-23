import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum TireState { ok, alert, add }

class TireSlot extends StatelessWidget {
  final TireState state;
  final String value;
  final String label;
  final VoidCallback? onTap;
  const TireSlot({
    super.key,
    required this.state,
    this.value = '',
    required this.label,
    this.onTap,
    // kept for call-site compatibility, no longer used
    double fraction = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = state == TireState.alert;
    final isAdd = state == TireState.add;
    final accent = isAlert ? AppColors.redText : AppColors.cyan;

    final Color bg = isAdd
        ? AppColors.cyan.withOpacity(0.06)
        : isAlert
            ? AppColors.red.withOpacity(0.10)
            : Colors.white.withOpacity(0.07);
    final Color line = isAdd
        ? AppColors.cyan.withOpacity(0.5)
        : isAlert
            ? AppColors.red.withOpacity(0.5)
            : Colors.white.withOpacity(0.16);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: bg,
          border: Border.all(color: line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdd)
              SizedBox(
                width: 62,
                height: 62,
                child: CustomPaint(
                  painter: _DashedCircle(AppColors.cyan.withOpacity(0.6)),
                  child: const Center(
                      child: Icon(Icons.add, color: AppColors.cyan, size: 26)),
                ),
              )
            else
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.07),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value,
                        style: AppText.chakra(
                            size: 16,
                            color: isAlert ? AppColors.redText : AppColors.text)),
                    Text('BAR',
                        style: AppText.mono(size: 7, color: AppColors.dimmer)),
                  ],
                ),
              ),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppText.mono(
                size: 10,
                color: isAdd
                    ? AppColors.cyan
                    : isAlert
                        ? AppColors.redText
                        : AppColors.dimmer,
                spacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  final Color color;
  _DashedCircle(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = size.width / 2 - 1;
    final c = Offset(size.width / 2, size.height / 2);
    const dash = 0.25, gap = 0.32;
    double a = 0;
    while (a < 2 * pi) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, dash, false, paint);
      a += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
