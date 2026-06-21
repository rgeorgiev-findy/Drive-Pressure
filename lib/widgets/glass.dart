import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted glass card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? border;
  final Color? fill;
  final bool blur;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.border,
    this.fill,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill ?? Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? Colors.white.withOpacity(0.14)),
      ),
      child: child,
    );
    if (!blur) {
      return ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: content,
      ),
    );
  }
}
