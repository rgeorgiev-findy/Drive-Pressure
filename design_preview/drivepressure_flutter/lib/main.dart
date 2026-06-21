import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const DrivePressureApp());

class DrivePressureApp extends StatelessWidget {
  const DrivePressureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DrivePressure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyan,
          surface: AppColors.bg,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
