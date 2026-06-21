import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'models/tire_sensor.dart';
import 'services/ble_service.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'screens/vehicle_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/limits_screen.dart';
import 'screens/tire_detail_screen.dart';
import 'screens/pair_ble_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _btOff = false;
  StreamSubscription<BluetoothAdapterState>? _btSub;

  @override
  void initState() {
    super.initState();
    BleService.instance.startScan();

    _btSub = FlutterBluePlus.adapterState.listen((state) {
      final off = state != BluetoothAdapterState.on;
      if (off != _btOff) {
        setState(() => _btOff = off);
        // Re-start scan when BT comes back on
        if (!off) BleService.instance.startScan();
      }
    });
  }

  @override
  void dispose() {
    _btSub?.cancel();
    BleService.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      VehicleScreen(
        onOpenTire: (pos, packet) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TireDetailScreen(position: pos, sensor: packet),
          ),
        ),
        onAddTire: (pos) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PairBleScreen(tirePosition: pos)),
        ),
      ),
      const AlertsScreen(),
      const LimitsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Bluetooth off banner ──────────────────────────────────────────
          if (_btOff)
            Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF1A0A0A),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 6,
                  bottom: 10,
                  left: 16,
                  right: 16,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_disabled_rounded,
                        color: AppColors.redText, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bluetooth is off — enable it to receive sensor data',
                        style: AppText.mono(
                            size: 12, color: AppColors.redText),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        // On Android 12+ we can't auto-enable BT; open settings
                        await FlutterBluePlus.turnOn();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.redText.withOpacity(0.5)),
                        ),
                        child: Text('ENABLE',
                            style: AppText.mono(
                                size: 11, color: AppColors.redText)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _index,
        onTap: (v) => setState(() => _index = v),
      ),
    );
  }
}
