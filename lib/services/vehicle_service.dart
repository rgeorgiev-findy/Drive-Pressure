import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tire_sensor.dart';

// ── Enums & Model ─────────────────────────────────────────────────────────────

enum VehicleType { car, trailer2, trailer4 }

extension VehicleTypeX on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.car:      return 'Car';
      case VehicleType.trailer2: return 'Trailer (2-wheel)';
      case VehicleType.trailer4: return 'Trailer (4-wheel)';
    }
  }

  String get shortLabel {
    switch (this) {
      case VehicleType.car:      return 'CAR';
      case VehicleType.trailer2: return 'TRAILER·2';
      case VehicleType.trailer4: return 'TRAILER·4';
    }
  }

  bool get isTrailer => this == VehicleType.trailer2 || this == VehicleType.trailer4;

  /// Tire positions that belong to this vehicle type.
  List<TirePosition> get positions {
    switch (this) {
      case VehicleType.car:
        return [TirePosition.fl, TirePosition.fr, TirePosition.rl, TirePosition.rr];
      case VehicleType.trailer2:
        return [TirePosition.l, TirePosition.r];
      case VehicleType.trailer4:
        return [TirePosition.fl, TirePosition.fr, TirePosition.rl, TirePosition.rr];
    }
  }
}

class Vehicle {
  final String id;
  final String name;
  final VehicleType type;

  const Vehicle({required this.id, required this.name, required this.type});

  Map<String, String> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
      };

  factory Vehicle.fromMap(Map<String, String> map) => Vehicle(
        id: map['id']!,
        name: map['name']!,
        type: VehicleType.values.firstWhere((t) => t.name == map['type']),
      );

  @override
  bool operator ==(Object other) => other is Vehicle && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── VehicleService ────────────────────────────────────────────────────────────

class VehicleService {
  static VehicleService? _instance;
  static VehicleService get instance => _instance!;

  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  VehicleService._(this._prefs);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = VehicleService._(prefs);
  }

  // ── Preference keys ──────────────────────────────────────────────────────

  static const _keyIds       = 'vs_vehicle_ids';
  static const _keyActiveCar = 'vs_active_car';
  static const _keyActiveTrailer = 'vs_active_trailer';

  String _keyName(String id) => 'vs_name_$id';
  String _keyType(String id) => 'vs_type_$id';
  String _keyMac(String vehicleId, TirePosition pos) =>
      'vs_mac_${vehicleId}_${pos.name}';

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<String> _ids() => _prefs.getStringList(_keyIds) ?? [];

  void _notify() => _changes.add(null);

  // ── Vehicle CRUD ─────────────────────────────────────────────────────────

  List<Vehicle> get vehicles {
    return _ids().map((id) {
      final name = _prefs.getString(_keyName(id)) ?? id;
      final typeName = _prefs.getString(_keyType(id)) ?? VehicleType.car.name;
      final type = VehicleType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => VehicleType.car,
      );
      return Vehicle(id: id, name: name, type: type);
    }).toList();
  }

  List<Vehicle> get cars =>
      vehicles.where((v) => v.type == VehicleType.car).toList();

  List<Vehicle> get trailers =>
      vehicles.where((v) => v.type.isTrailer).toList();

  Future<Vehicle> addVehicle(String name, VehicleType type) async {
    final id = _generateId();
    final ids = _ids()..add(id);
    await _prefs.setStringList(_keyIds, ids);
    await _prefs.setString(_keyName(id), name);
    await _prefs.setString(_keyType(id), type.name);
    _notify();
    return Vehicle(id: id, name: name, type: type);
  }

  Future<void> removeVehicle(String vehicleId) async {
    // Clear sensor pairings for all positions
    for (final pos in TirePosition.values) {
      await _prefs.remove(_keyMac(vehicleId, pos));
    }
    await _prefs.remove(_keyName(vehicleId));
    await _prefs.remove(_keyType(vehicleId));

    // Update ids list
    final ids = _ids()..remove(vehicleId);
    await _prefs.setStringList(_keyIds, ids);

    // Clear active selections if they pointed to this vehicle
    if (activeCarId == vehicleId) await _prefs.remove(_keyActiveCar);
    if (activeTrailerId == vehicleId) await _prefs.remove(_keyActiveTrailer);

    _notify();
  }

  // ── Active selection ─────────────────────────────────────────────────────

  String? get activeCarId => _prefs.getString(_keyActiveCar);
  String? get activeTrailerId => _prefs.getString(_keyActiveTrailer);

  Vehicle? get activeCar {
    final id = activeCarId;
    if (id == null) return null;
    try {
      return vehicles.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Vehicle? get activeTrailer {
    final id = activeTrailerId;
    if (id == null) return null;
    try {
      return vehicles.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> setActiveCar(String? vehicleId) async {
    if (vehicleId == null) {
      await _prefs.remove(_keyActiveCar);
    } else {
      await _prefs.setString(_keyActiveCar, vehicleId);
    }
    _notify();
  }

  Future<void> setActiveTrailer(String? vehicleId) async {
    if (vehicleId == null) {
      await _prefs.remove(_keyActiveTrailer);
    } else {
      await _prefs.setString(_keyActiveTrailer, vehicleId);
    }
    _notify();
  }

  // ── Sensor pairing ───────────────────────────────────────────────────────

  Future<void> pairSensor(
      String vehicleId, TirePosition position, String mac) async {
    await _prefs.setString(_keyMac(vehicleId, position), mac);
    _notify();
  }

  Future<void> unpairSensor(String vehicleId, TirePosition position) async {
    await _prefs.remove(_keyMac(vehicleId, position));
    _notify();
  }

  String? getMac(String vehicleId, TirePosition position) =>
      _prefs.getString(_keyMac(vehicleId, position));

  Map<TirePosition, String> getPairedMacs(String vehicleId) {
    final result = <TirePosition, String>{};
    for (final pos in TirePosition.values) {
      final mac = getMac(vehicleId, pos);
      if (mac != null) result[pos] = mac;
    }
    return result;
  }

  // ── Utils ────────────────────────────────────────────────────────────────

  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = (ts * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFF;
    return '${ts.toRadixString(16)}${rand.toRadixString(16)}';
  }

  void dispose() => _changes.close();
}
