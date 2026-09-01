import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/ble_service.dart';
import 'services/carplay_service.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'screens/vehicle_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/limits_screen.dart';
import 'screens/tire_detail_screen.dart';
import 'screens/pair_ble_screen.dart';
import 'screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  BluetoothAdapterState _btState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _btSub;
  StreamSubscription<bool>? _carplaySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BleService.instance.startScan();

    _btSub = FlutterBluePlus.adapterState.listen((state) {
      if (state == _btState) return;
      setState(() => _btState = state);
      if (state == BluetoothAdapterState.on) BleService.instance.startScan();
    });

    // When CarPlay connects while app is backgrounded, resume BLE scanning.
    if (Platform.isIOS) {
      _carplaySub = CarPlayService.instance.connectionState.listen((connected) {
        if (connected) BleService.instance.startScan();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isIOS) return;
    if (state == AppLifecycleState.paused) {
      // Only stop BLE when going to background WITHOUT CarPlay active.
      if (!CarPlayService.instance.isConnected) {
        BleService.instance.stopScan();
      }
    } else if (state == AppLifecycleState.resumed) {
      BleService.instance.startScan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _btSub?.cancel();
    _carplaySub?.cancel();
    BleService.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      VehicleScreen(
        onOpenTire: (pos, packet, {String? vehicleId}) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TireDetailScreen(
                position: pos, sensor: packet, vehicleId: vehicleId),
          ),
        ),
        onAddTire: (pos, {String? vehicleId}) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PairBleScreen(
              tirePosition: pos,
              vehicleId: vehicleId,
            ),
          ),
        ),
      ),
      const AlertsScreen(),
      const LimitsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Bluetooth banner ──────────────────────────────────────────────
          if (_btState == BluetoothAdapterState.off ||
              _btState == BluetoothAdapterState.unauthorized ||
              _btState == BluetoothAdapterState.unavailable)
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
                        _btState == BluetoothAdapterState.unauthorized
                            ? 'Allow Bluetooth access in Settings to receive sensor data'
                            : 'Bluetooth is off — enable it to receive sensor data',
                        style: AppText.mono(
                            size: 12, color: AppColors.redText),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_btState == BluetoothAdapterState.unauthorized) {
                          await openAppSettings();
                        } else {
                          await FlutterBluePlus.turnOn();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.redText.withOpacity(0.5)),
                        ),
                        child: Text(
                            _btState == BluetoothAdapterState.unauthorized
                                ? 'SETTINGS'
                                : 'ENABLE',
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
