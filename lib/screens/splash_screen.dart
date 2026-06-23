import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/tire_logo.dart';
import '../main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOffset;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.40, curve: Curves.easeOut)),
    );
    _titleOffset = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.22, 0.65, curve: Curves.easeOut)),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.22, 0.60, curve: Curves.easeOut)),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.40, 0.75, curve: Curves.easeOut)),
    );

    _ctrl.forward().then((_) {
      // Brief pause after animation then navigate automatically
      Future.delayed(const Duration(milliseconds: 600), _goToMain);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: const TireLogo(size: 116),
                  ),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: _titleOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _titleOffset.value),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                            text: 'Findy',
                            style: AppText.chakra(
                                size: 32,
                                color: AppColors.text,
                                spacing: -0.5)),
                        TextSpan(
                            text: 'TPMS',
                            style: AppText.chakra(
                                size: 32,
                                color: AppColors.cyan,
                                spacing: -0.5)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: _subtitleOpacity.value,
                  child: Text(
                    'LIVE TPMS · BLUETOOTH',
                    style: AppText.mono(
                        size: 11, color: AppColors.dimmer, spacing: 3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
