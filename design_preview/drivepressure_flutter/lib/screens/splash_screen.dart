import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/buttons.dart';
import '../widgets/tire_logo.dart';
import '../main_shell.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const StatusRow(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TireLogo(size: 116),
                      const SizedBox(height: 14),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(text: 'Drive', style: AppText.chakra(size: 30, color: AppColors.text, spacing: -0.5)),
                          TextSpan(text: 'Pressure', style: AppText.chakra(size: 30, color: AppColors.cyan, spacing: -0.5)),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text('LIVE TPMS · BLUETOOTH',
                          style: AppText.mono(size: 11, color: AppColors.dimmer, spacing: 3)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                child: CyanButton(
                  'GET STARTED',
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
