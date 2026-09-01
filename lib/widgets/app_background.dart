import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Warm dark automotive background with subtle orange-tinted ambient blobs.
class AppBackground extends StatelessWidget {
  final Widget child;
  final Color glow;
  const AppBackground({super.key, required this.child, this.glow = AppColors.orange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Stack(
        children: [
          // Top-left: primary glow (orange by default, red on alert screens)
          Positioned(top: -140, left: -70, child: _blob(glow.withOpacity(0.20), 380)),
          // Top-right: warm amber undertone
          Positioned(top: 40, right: -90, child: _blob(const Color(0xFF3A1806).withOpacity(0.50), 340)),
          // Bottom-left: deep warm dark
          Positioned(bottom: -160, left: 10, child: _blob(const Color(0xFF1E0E04).withOpacity(0.55), 400)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _blob(Color c, double d) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c, c.withOpacity(0)]),
        ),
      );
}
