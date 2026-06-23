import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/sensor_store.dart';
import 'services/ble_service.dart';
import 'services/limits_service.dart';
import 'services/alerts_service.dart';
import 'services/trend_service.dart';
import 'services/vehicle_service.dart';
import 'services/carplay_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await SensorStore.init();
  await VehicleService.init();
  await BleService.instance.init();
  await LimitsService.instance.init();
  AlertsService.instance.init();
  TrendService.instance.init();
  CarPlayService.instance.init();
  runApp(const DrivePressureApp());
}

class DrivePressureApp extends StatelessWidget {
  const DrivePressureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drive Pressure',
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
