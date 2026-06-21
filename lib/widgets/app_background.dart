import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Cool gradient-mesh background (AURA). [glow] tints the top halo.
class AppBackground extends StatelessWidget {
  final Widget child;
  final Color glow;
  const AppBackground({super.key, required this.child, this.glow = AppColors.cyan});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Stack(
        children: [
          Positioned(top: -140, left: -70, child: _blob(glow.withOpacity(0.22), 380)),
          Positioned(top: 40, right: -90, child: _blob(const Color(0xFF134A52).withOpacity(0.55), 340)),
          Positioned(bottom: -160, left: 10, child: _blob(const Color(0xFF11365A).withOpacity(0.6), 400)),
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
