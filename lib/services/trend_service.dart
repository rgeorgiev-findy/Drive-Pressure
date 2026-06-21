import 'dart:async';
import '../models/tire_sensor.dart';
import 'ble_service.dart';
import 'sensor_store.dart';

/// Accumulates pressure and temperature readings per tire position.
/// Runs independently of any screen — data builds up as long as the app is alive.
class TrendService {
  static final TrendService instance = TrendService._();
  TrendService._();

  final Map<TirePosition, List<double>> pressure = {};
  final Map<TirePosition, List<double>> temp = {};

  // Emits the position every time a new data point is added
  final _ctrl = StreamController<TirePosition>.broadcast();
  Stream<TirePosition> get updates => _ctrl.stream;

  void init() {
    BleService.instance.packets.listen(_onPacket);
    SensorStore.instance.changes.listen((_) => _pruneUnpaired());
  }

  void _onPacket(SensorPacket packet) {
    final pos = _positionOf(packet.mac);
    if (pos == null) return;
    pressure.putIfAbsent(pos, () => []).add(packet.pressureBar);
    temp.putIfAbsent(pos, () => []).add(packet.temperatureC.toDouble());
    _ctrl.add(pos);
  }

  void _pruneUnpaired() {
    final paired = SensorStore.instance.pairedMacs;
    pressure.removeWhere((pos, _) => !paired.containsKey(pos));
    temp.removeWhere((pos, _) => !paired.containsKey(pos));
  }

  TirePosition? _positionOf(String mac) {
    for (final e in SensorStore.instance.pairedMacs.entries) {
      if (e.value == mac) return e.key;
    }
    return null;
  }
}
