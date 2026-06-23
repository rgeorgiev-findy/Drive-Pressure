import 'dart:async';
import '../models/tire_sensor.dart';
import 'ble_service.dart';
import 'sensor_store.dart';
import 'vehicle_service.dart';

/// Accumulates pressure and temperature readings per tire position.
/// Runs independently of any screen — data builds up as long as the app is alive.
class TrendService {
  static final TrendService instance = TrendService._();
  TrendService._();

  final Map<TirePosition, List<double>> pressure = {};
  final Map<TirePosition, List<double>> temp = {};

  final _ctrl = StreamController<TirePosition>.broadcast();
  Stream<TirePosition> get updates => _ctrl.stream;

  void init() {
    BleService.instance.packets.listen(_onPacket);
  }

  void _onPacket(SensorPacket packet) {
    final pos = _positionOf(packet.mac);
    if (pos == null) return;
    pressure.putIfAbsent(pos, () => []).add(packet.pressureBar);
    temp.putIfAbsent(pos, () => []).add(packet.temperatureC.toDouble());
    _ctrl.add(pos);
  }

  TirePosition? _positionOf(String mac) {
    // Check legacy SensorStore
    for (final e in SensorStore.instance.pairedMacs.entries) {
      if (e.value == mac) return e.key;
    }
    // Check active car and trailer in VehicleService
    final vs = VehicleService.instance;
    for (final vehicle in [vs.activeCar, vs.activeTrailer]) {
      if (vehicle == null) continue;
      for (final e in vs.getPairedMacs(vehicle.id).entries) {
        if (e.value == mac) return e.key;
      }
    }
    return null;
  }
}
