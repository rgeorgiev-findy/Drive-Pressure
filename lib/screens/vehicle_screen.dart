import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tire_sensor.dart';
import '../services/ble_service.dart';
import '../services/sensor_store.dart';
import '../services/alerts_service.dart';
import '../services/limits_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/tire_logo.dart';
import '../widgets/tire_slot.dart';

class VehicleScreen extends StatefulWidget {
  final void Function(TirePosition, SensorPacket?) onOpenTire;
  final void Function(TirePosition) onAddTire;

  const VehicleScreen({
    super.key,
    required this.onOpenTire,
    required this.onAddTire,
  });

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  Map<TirePosition, String> _pairedMacs = {};
  Map<String, SensorPacket> _readings = {};
  StreamSubscription<SensorPacket>? _bleSub;
  StreamSubscription<void>? _storeSub;
  StreamSubscription<void>? _alertSub;

  @override
  void initState() {
    super.initState();
    _reload();
    _storeSub = SensorStore.instance.changes.listen((_) => _reload());
    _bleSub = BleService.instance.packets.listen(_onPacket);
    _alertSub = AlertsService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _pairedMacs = SensorStore.instance.pairedMacs);
  }

  void _onPacket(SensorPacket packet) {
    if (!_pairedMacs.containsValue(packet.mac)) return;
    if (!mounted) return;
    setState(() => _readings[packet.mac] = packet);
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _storeSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  SensorPacket? _packetFor(TirePosition pos) {
    final mac = _pairedMacs[pos];
    if (mac == null) return null;
    return _readings[mac] ?? BleService.instance.latest[mac];
  }

  @override
  Widget build(BuildContext context) {
    final alertCount = AlertsService.instance.count;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const StatusRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
              child: Row(
                children: [
                  const TireLogo(size: 40),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: 'Drive',
                          style: AppText.chakra(
                              size: 17, color: AppColors.text, spacing: -0.3)),
                      TextSpan(
                          text: 'Pressure',
                          style: AppText.chakra(
                              size: 17, color: AppColors.cyan, spacing: -0.3)),
                    ]),
                  ),
                  const Spacer(),
                  if (alertCount > 0)
                    _pill('$alertCount ALERT${alertCount > 1 ? 'S' : ''}',
                        AppColors.redText),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 340,
                  height: 392,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Car body
                      Container(
                        width: 120,
                        height: 272,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(58),
                              bottom: Radius.circular(52)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.white.withOpacity(0.03)
                            ],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                      ),
                      // Windshield
                      Align(
                        alignment: const Alignment(0, -0.42),
                        child: Container(
                          width: 92,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(34),
                                bottom: Radius.circular(14)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.cyan.withOpacity(0.16),
                                AppColors.cyan.withOpacity(0.03)
                              ],
                            ),
                            border:
                                Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                        ),
                      ),
                      // Roof panel
                      Align(
                        alignment: const Alignment(0, 0.16),
                        child: Container(
                          width: 90,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.05),
                            border:
                                Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        child: Text('FRONT',
                            style: AppText.mono(
                                size: 9, color: AppColors.muted, spacing: 3)),
                      ),
                      // Tire slots
                      Positioned(
                          left: 0, top: 50, child: _slot(TirePosition.fl)),
                      Positioned(
                          right: 0, top: 50, child: _slot(TirePosition.fr)),
                      Positioned(
                          left: 0, bottom: 50, child: _slot(TirePosition.rl)),
                      Positioned(
                          right: 0, bottom: 50, child: _slot(TirePosition.rr)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(TirePosition pos) {
    final packet = _packetFor(pos);
    final paired = _pairedMacs.containsKey(pos);

    if (!paired) {
      return TireSlot(
        state: TireState.add,
        label: '${pos.shortLabel} · ADD',
        onTap: () => widget.onAddTire(pos),
      );
    }

    if (packet == null) {
      return TireSlot(
        state: TireState.ok,
        value: '--',
        label: '${pos.shortLabel} · …',
        fraction: 0.0,
        onTap: () => widget.onOpenTire(pos, null),
      );
    }

    final isLow = packet.pressureBar < LimitsService.instance.minPressureBar;
    final fraction = (packet.pressureBar / 3.5).clamp(0.0, 1.0);
    final tempLabel = '${pos.shortLabel} · ${packet.temperatureC}°';

    return TireSlot(
      state: isLow ? TireState.alert : TireState.ok,
      value: packet.pressureBar.toStringAsFixed(1),
      label: tempLabel,
      fraction: fraction,
      onTap: () => widget.onOpenTire(pos, packet),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Text(t, style: AppText.mono(size: 11, color: c)),
      );
}
