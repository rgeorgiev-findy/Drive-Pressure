import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tire_sensor.dart';

class SensorStore {
  static SensorStore? _instance;
  static SensorStore get instance => _instance!;

  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  SensorStore._(this._prefs);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SensorStore._(prefs);
  }

  static const _prefix = 'paired_mac_';

  Map<TirePosition, String> get pairedMacs {
    final result = <TirePosition, String>{};
    for (final pos in TirePosition.values) {
      final mac = _prefs.getString('$_prefix${pos.name}');
      if (mac != null) result[pos] = mac;
    }
    return result;
  }

  Future<void> saveSensor(TirePosition position, String mac) async {
    await _prefs.setString('$_prefix${position.name}', mac);
    _changes.add(null);
  }

  Future<void> removeSensor(TirePosition position) async {
    await _prefs.remove('$_prefix${position.name}');
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
