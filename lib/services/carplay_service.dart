import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/tire_sensor.dart';
import 'alerts_service.dart';
import 'ble_service.dart';
import 'limits_service.dart';
import 'trend_service.dart';
import 'vehicle_service.dart';

/// Sends live tire data to the native iOS CarPlay scene via a MethodChannel.
/// All rendering is done in Swift (CarPlaySceneDelegate.swift).
class CarPlayService {
  static final CarPlayService instance = CarPlayService._();
  CarPlayService._();

  static const _channel = MethodChannel('eu.findy.drivePressure/carplay');

  StreamSubscription<void>? _vehicleSub;
  StreamSubscription<TirePosition>? _trendSub;
  StreamSubscription<void>? _alertSub;
  Timer? _debounce;

  bool _connected = false;
  bool get isConnected => _connected;

  // Track which alerts have already been shown on CarPlay to avoid re-showing them
  final _shownAlerts = <String>{};

  /// Fires true when CarPlay connects, false when it disconnects.
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionController.stream;

  void init() {
    if (!Platform.isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'connected') {
        _connected = true;
        _connectionController.add(true);
        _sendUpdate();
        _forwardAlerts(); // show any active alerts immediately on connect
      } else if (call.method == 'disconnected') {
        _connected = false;
        _connectionController.add(false);
      }
    });
    _sendUpdate();
    _vehicleSub = VehicleService.instance.changes.listen((_) => _sendUpdate());
    _trendSub   = TrendService.instance.updates.listen(_onTrend);
    _alertSub   = AlertsService.instance.changes.listen((_) => _forwardAlerts());
  }

  void _forwardAlerts() {
    if (!_connected) return;
    final active = AlertsService.instance.active;
    // Prune keys for resolved alerts
    final activeKeys = active.map((a) => '${a.pos.name}_${a.type.name}').toSet();
    _shownAlerts.retainAll(activeKeys);
    // Find alerts not yet shown on CarPlay
    final newAlerts = active
        .where((a) => !_shownAlerts.contains('${a.pos.name}_${a.type.name}'))
        .toList();
    if (newAlerts.isEmpty) return;
    for (final a in newAlerts) {
      _shownAlerts.add('${a.pos.name}_${a.type.name}');
    }
    // Send ONE combined alert to avoid CPInterfaceController crash from rapid calls
    final title = newAlerts.length == 1
        ? newAlerts.first.message
        : 'TPMS — ${newAlerts.length} alerts';
    final body = newAlerts.map((a) => a.detail).join('  ·  ');
    _channel.invokeMethod('alert', {'title': title, 'body': body}).catchError((_) {});
  }

  void _onTrend(TirePosition _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _sendUpdate);
  }

  Future<void> _sendUpdate() async {
    try {
      await _channel.invokeMethod('update', _payload());
    } catch (_) {}
  }

  Map<String, dynamic> _payload() {
    final vs = VehicleService.instance;
    final vehicles = <Map<String, dynamic>>[];

    for (final v in [vs.activeCar, vs.activeTrailer].whereType<Vehicle>()) {
      final macs = vs.getPairedMacs(v.id);
      final tires = <String, dynamic>{};

      for (final pos in v.type.positions) {
        final mac = macs[pos];
        final packet = mac != null ? BleService.instance.latest[mac] : null;
        final isLow = packet != null &&
            packet.pressureBar < LimitsService.instance.minPressureBar;
        tires[pos.name] = {
          'pressure': packet?.pressureBar,
          'temp': packet?.temperatureC,
          'isLow': isLow,
          'connected': packet != null,
          'pressureHistory': _recent(TrendService.instance.pressure[pos]),
          'tempHistory': _recent(TrendService.instance.temp[pos]),
        };
      }

      vehicles.add({
        'id': v.id,
        'name': v.name,
        'type': v.type.name,
        'tires': tires,
      });
    }

    return {'vehicles': vehicles};
  }

  List<double> _recent(List<double>? data) {
    if (data == null || data.length < 2) return [];
    return data.length > 20 ? data.sublist(data.length - 20) : List.of(data);
  }

  void dispose() {
    _vehicleSub?.cancel();
    _trendSub?.cancel();
    _alertSub?.cancel();
    _debounce?.cancel();
  }
}
