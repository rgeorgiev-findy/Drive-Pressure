import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tire_sensor.dart';
import '../services/ble_service.dart';
import '../services/sensor_store.dart';
import '../services/alerts_service.dart';
import '../services/limits_service.dart';
import '../services/vehicle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/tire_logo.dart';
import '../widgets/tire_slot.dart';

class VehicleScreen extends StatefulWidget {
  final void Function(TirePosition, SensorPacket?) onOpenTire;
  final void Function(TirePosition, {String? vehicleId}) onAddTire;

  const VehicleScreen({
    super.key,
    required this.onOpenTire,
    required this.onAddTire,
  });

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  // Legacy SensorStore (kept for backward compat)
  Map<TirePosition, String> _legacyMacs = {};

  // VehicleService state
  Vehicle? _activeCar;
  Vehicle? _activeTrailer;
  Map<TirePosition, String> _carMacs = {};
  Map<TirePosition, String> _trailerMacs = {};

  Map<String, SensorPacket> _readings = {};
  StreamSubscription<SensorPacket>? _bleSub;
  StreamSubscription<void>? _storeSub;
  StreamSubscription<void>? _vehicleSub;
  StreamSubscription<void>? _alertSub;

  @override
  void initState() {
    super.initState();
    _reload();
    _storeSub = SensorStore.instance.changes.listen((_) => _reload());
    _vehicleSub = VehicleService.instance.changes.listen((_) => _reload());
    _bleSub = BleService.instance.packets.listen(_onPacket);
    _alertSub = AlertsService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _reload() {
    if (!mounted) return;
    final vs = VehicleService.instance;
    setState(() {
      _legacyMacs = SensorStore.instance.pairedMacs;
      _activeCar = vs.activeCar;
      _activeTrailer = vs.activeTrailer;
      _carMacs = _activeCar != null
          ? vs.getPairedMacs(_activeCar!.id)
          : {};
      _trailerMacs = _activeTrailer != null
          ? vs.getPairedMacs(_activeTrailer!.id)
          : {};
    });
  }

  void _onPacket(SensorPacket packet) {
    final allMacs = {
      ..._legacyMacs.values,
      ..._carMacs.values,
      ..._trailerMacs.values,
    };
    if (!allMacs.contains(packet.mac)) return;
    if (!mounted) return;
    setState(() => _readings[packet.mac] = packet);
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _storeSub?.cancel();
    _vehicleSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  // ── Packet lookup ─────────────────────────────────────────────────────────

  SensorPacket? _packetFor(TirePosition pos, Map<TirePosition, String> macs) {
    final mac = macs[pos];
    if (mac == null) return null;
    return _readings[mac] ?? BleService.instance.latest[mac];
  }

  // ── Whether we use VehicleService or legacy SensorStore ──────────────────

  bool get _hasVehicleConfig =>
      _activeCar != null || _activeTrailer != null;

  // ── Active configuration label ────────────────────────────────────────────

  String get _configLabel {
    if (!_hasVehicleConfig) return 'No vehicle selected';
    final parts = <String>[];
    if (_activeCar != null) parts.add(_activeCar!.name);
    if (_activeTrailer != null) parts.add(_activeTrailer!.name);
    return parts.join(' + ');
  }

  // ── Bottom sheet: pick active car and trailer ─────────────────────────────

  void _showVehiclePicker() {
    final vs = VehicleService.instance;
    final cars = vs.cars;
    final trailers = vs.trailers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VehiclePickerSheet(
        cars: cars,
        trailers: trailers,
        activeCarId: vs.activeCarId,
        activeTrailerId: vs.activeTrailerId,
        onSelectCar: (id) async {
          await vs.setActiveCar(id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        onSelectTrailer: (id) async {
          await vs.setActiveTrailer(id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final alertCount = AlertsService.instance.count;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const StatusRow(),
            // Header
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
                              size: 17,
                              color: AppColors.text,
                              spacing: -0.3)),
                      TextSpan(
                          text: 'Pressure',
                          style: AppText.chakra(
                              size: 17,
                              color: AppColors.cyan,
                              spacing: -0.3)),
                    ]),
                  ),
                  const Spacer(),
                  if (alertCount > 0)
                    _pill('$alertCount ALERT${alertCount > 1 ? 'S' : ''}',
                        AppColors.redText),
                ],
              ),
            ),
            // Vehicle selector strip
            GestureDetector(
              onTap: _showVehiclePicker,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasVehicleConfig
                          ? Icons.directions_car_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 16,
                      color: _hasVehicleConfig
                          ? AppColors.cyan
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _configLabel,
                        style: AppText.mono(
                          size: 11,
                          color: _hasVehicleConfig
                              ? AppColors.textSoft
                              : AppColors.muted,
                          spacing: 0.5,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.dimmer),
                  ],
                ),
              ),
            ),
            // Main content
            Expanded(
              child: _hasVehicleConfig
                  ? _vehicleLayout()
                  : _legacyLayout(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Legacy layout (original 4-car design, uses SensorStore) ──────────────

  Widget _legacyLayout() {
    return Center(
      child: SizedBox(
        width: 340,
        height: 392,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _carBody(),
            Positioned(
              top: 0,
              child: Text('FRONT',
                  style: AppText.mono(
                      size: 9, color: AppColors.muted, spacing: 3)),
            ),
            Positioned(
                left: 0,
                top: 50,
                child: _slotLegacy(TirePosition.fl)),
            Positioned(
                right: 0,
                top: 50,
                child: _slotLegacy(TirePosition.fr)),
            Positioned(
                left: 0,
                bottom: 50,
                child: _slotLegacy(TirePosition.rl)),
            Positioned(
                right: 0,
                bottom: 50,
                child: _slotLegacy(TirePosition.rr)),
          ],
        ),
      ),
    );
  }

  // ── Vehicle layout: car and/or trailer ───────────────────────────────────

  Widget _vehicleLayout() {
    final hasCar = _activeCar != null;
    final hasTrailer = _activeTrailer != null;

    if (hasCar && hasTrailer) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            _carLayout(_activeCar!, _carMacs),
            // Connector
            _connector(),
            _trailerLayout(_activeTrailer!, _trailerMacs),
            const SizedBox(height: 16),
          ],
        ),
      );
    } else if (hasCar) {
      return Center(child: _carLayout(_activeCar!, _carMacs));
    } else if (hasTrailer) {
      return Center(child: _trailerLayout(_activeTrailer!, _trailerMacs));
    }
    return const SizedBox.shrink();
  }

  // ── Car drawing ───────────────────────────────────────────────────────────

  Widget _carLayout(Vehicle vehicle, Map<TirePosition, String> macs) {
    return SizedBox(
      width: 340,
      height: 392,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _carBody(),
          Positioned(
            top: 0,
            child: Text('FRONT · ${vehicle.name}',
                style:
                    AppText.mono(size: 9, color: AppColors.muted, spacing: 3)),
          ),
          Positioned(
              left: 0,
              top: 50,
              child: _slotVehicle(TirePosition.fl, vehicle, macs)),
          Positioned(
              right: 0,
              top: 50,
              child: _slotVehicle(TirePosition.fr, vehicle, macs)),
          Positioned(
              left: 0,
              bottom: 50,
              child: _slotVehicle(TirePosition.rl, vehicle, macs)),
          Positioned(
              right: 0,
              bottom: 50,
              child: _slotVehicle(TirePosition.rr, vehicle, macs)),
        ],
      ),
    );
  }

  Widget _carBody() {
    return Stack(
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
              border: Border.all(color: Colors.white.withOpacity(0.14)),
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
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Trailer drawing ───────────────────────────────────────────────────────

  Widget _trailerLayout(Vehicle vehicle, Map<TirePosition, String> macs) {
    final is2wheel = vehicle.type == VehicleType.trailer2;

    if (is2wheel) {
      return SizedBox(
        width: 340,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Trailer body
            Container(
              width: 160,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.02)
                  ],
                ),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15)),
              ),
            ),
            Positioned(
              top: 0,
              child: Text(vehicle.name,
                  style: AppText.mono(
                      size: 9, color: AppColors.muted, spacing: 3)),
            ),
            Positioned(
                left: 0,
                child: _slotVehicle(TirePosition.l, vehicle, macs,
                    compact: true)),
            Positioned(
                right: 0,
                child: _slotVehicle(TirePosition.r, vehicle, macs,
                    compact: true)),
          ],
        ),
      );
    }

    // 4-wheel trailer
    return SizedBox(
      width: 340,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Trailer body
          Container(
            width: 120,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02)
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
          ),
          Positioned(
            top: 0,
            child: Text(vehicle.name,
                style: AppText.mono(
                    size: 9, color: AppColors.muted, spacing: 3)),
          ),
          Positioned(
              left: 0,
              top: 20,
              child: _slotVehicle(TirePosition.fl, vehicle, macs)),
          Positioned(
              right: 0,
              top: 20,
              child: _slotVehicle(TirePosition.fr, vehicle, macs)),
          Positioned(
              left: 0,
              bottom: 20,
              child: _slotVehicle(TirePosition.rl, vehicle, macs)),
          Positioned(
              right: 0,
              bottom: 20,
              child: _slotVehicle(TirePosition.rr, vehicle, macs)),
        ],
      ),
    );
  }

  Widget _connector() {
    return SizedBox(
      height: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 2,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.dimmer.withOpacity(0.6),
                  AppColors.amber.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tire slot builders ────────────────────────────────────────────────────

  Widget _slotLegacy(TirePosition pos) {
    final packet = _packetFor(pos, _legacyMacs);
    final paired = _legacyMacs.containsKey(pos);

    if (!paired) {
      return TireSlot(
        state: TireState.add,
        label: '${pos.shortLabel} · ADD',
        onTap: () => widget.onAddTire(pos),
      );
    }
    return _buildSlotContent(pos, packet,
        onAdd: () => widget.onAddTire(pos),
        onOpen: () => widget.onOpenTire(pos, null),
        onOpenWithPacket: (p) => widget.onOpenTire(pos, p));
  }

  Widget _slotVehicle(
    TirePosition pos,
    Vehicle vehicle,
    Map<TirePosition, String> macs, {
    bool compact = false,
  }) {
    final packet = _packetFor(pos, macs);
    final paired = macs.containsKey(pos);

    if (!paired) {
      return TireSlot(
        state: TireState.add,
        label: '${pos.shortLabel} · ADD',
        onTap: () => widget.onAddTire(pos, vehicleId: vehicle.id),
      );
    }
    return _buildSlotContent(pos, packet,
        onAdd: () => widget.onAddTire(pos, vehicleId: vehicle.id),
        onOpen: () => widget.onOpenTire(pos, null),
        onOpenWithPacket: (p) => widget.onOpenTire(pos, p));
  }

  Widget _buildSlotContent(
    TirePosition pos,
    SensorPacket? packet, {
    required VoidCallback onAdd,
    required VoidCallback onOpen,
    required void Function(SensorPacket) onOpenWithPacket,
  }) {
    if (packet == null) {
      return TireSlot(
        state: TireState.ok,
        value: '--',
        label: '${pos.shortLabel} · …',
        fraction: 0.0,
        onTap: onOpen,
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
      onTap: () => onOpenWithPacket(packet),
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

// ── Vehicle Picker Bottom Sheet ───────────────────────────────────────────────

class _VehiclePickerSheet extends StatelessWidget {
  final List<Vehicle> cars;
  final List<Vehicle> trailers;
  final String? activeCarId;
  final String? activeTrailerId;
  final void Function(String?) onSelectCar;
  final void Function(String?) onSelectTrailer;

  const _VehiclePickerSheet({
    required this.cars,
    required this.trailers,
    required this.activeCarId,
    required this.activeTrailerId,
    required this.onSelectCar,
    required this.onSelectTrailer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        left: 12,
        right: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white.withOpacity(0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Text('Active Configuration',
                style: AppText.chakra(size: 17, color: AppColors.text)),
          ),
          // Cars
          _sheetSection('CAR', AppColors.cyan, Icons.directions_car_rounded),
          _noneRow(
            isSelected: activeCarId == null,
            color: AppColors.cyan,
            onTap: () => onSelectCar(null),
          ),
          ...cars.map((v) => _vehicleRow(
                vehicle: v,
                isSelected: v.id == activeCarId,
                color: AppColors.cyan,
                onTap: () => onSelectCar(v.id),
              )),
          if (cars.isEmpty) _emptyRow('Add a car in Settings'),

          const SizedBox(height: 8),
          // Trailers
          _sheetSection(
              'TRAILER', AppColors.amber, Icons.rv_hookup_rounded),
          _noneRow(
            isSelected: activeTrailerId == null,
            color: AppColors.amber,
            onTap: () => onSelectTrailer(null),
          ),
          ...trailers.map((v) => _vehicleRow(
                vehicle: v,
                isSelected: v.id == activeTrailerId,
                color: AppColors.amber,
                onTap: () => onSelectTrailer(v.id),
              )),
          if (trailers.isEmpty) _emptyRow('Add a trailer in Settings'),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sheetSection(String label, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: AppText.mono(size: 10, color: color, spacing: 2)),
        ],
      ),
    );
  }

  Widget _noneRow({
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _sheetRow(
      label: 'None',
      sublabel: 'No vehicle',
      icon: Icons.block_rounded,
      iconColor: AppColors.muted,
      isSelected: isSelected,
      selectedColor: color,
      onTap: onTap,
    );
  }

  Widget _vehicleRow({
    required Vehicle vehicle,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _sheetRow(
      label: vehicle.name,
      sublabel: vehicle.type.label,
      icon: vehicle.type.isTrailer
          ? Icons.rv_hookup_rounded
          : Icons.directions_car_rounded,
      iconColor: color,
      isSelected: isSelected,
      selectedColor: color,
      onTap: onTap,
    );
  }

  Widget _sheetRow({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? selectedColor.withOpacity(0.10)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isSelected
                ? selectedColor.withOpacity(0.40)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppText.chakra(
                          size: 14,
                          color: isSelected
                              ? AppColors.text
                              : AppColors.textSoft)),
                  Text(sublabel,
                      style: AppText.mono(
                          size: 10, color: AppColors.dimmer, spacing: 0.3)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  size: 18, color: selectedColor),
          ],
        ),
      ),
    );
  }

  Widget _emptyRow(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        child: Text(text,
            style: AppText.mono(size: 11, color: AppColors.muted)),
      );
}
