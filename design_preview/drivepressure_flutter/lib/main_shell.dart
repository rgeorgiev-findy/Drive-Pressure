import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'screens/vehicle_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/limits_screen.dart';
import 'screens/tire_detail_screen.dart';
import 'screens/pair_ble_screen.dart';

/// Bottom-tab shell: Home · Alerts · Limits.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      VehicleScreen(
        onOpenTire: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TireDetailScreen()),
        ),
        onAddTire: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PairBleScreen()),
        ),
      ),
      const AlertsScreen(),
      const LimitsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomNav(
        current: _index,
        onTap: (v) => setState(() => _index = v),
      ),
    );
  }
}
