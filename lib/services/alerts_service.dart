import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tire_sensor.dart';
import 'ble_service.dart';
import 'sensor_store.dart';
import 'vehicle_service.dart';
import 'limits_service.dart';

enum AlertSeverity { critical, warning }
enum AlertType { lowPressure, highPressure, highTemp, batteryLow, fault }

class AlertEntry {
  final TirePosition pos;
  final AlertType type;
  final String message;
  final String detail;
  final DateTime timestamp;

  const AlertEntry({
    required this.pos,
    required this.type,
    required this.message,
    required this.detail,
    required this.timestamp,
  });

  AlertSeverity get severity => switch (type) {
    AlertType.lowPressure  => AlertSeverity.critical,
    AlertType.highPressure => AlertSeverity.critical,
    AlertType.highTemp     => AlertSeverity.warning,
    AlertType.batteryLow   => AlertSeverity.warning,
    AlertType.fault        => AlertSeverity.critical,
  };

  IconData get icon => switch (type) {
    AlertType.lowPressure  => Icons.warning_amber_rounded,
    AlertType.highPressure => Icons.compress_rounded,
    AlertType.highTemp     => Icons.thermostat_rounded,
    AlertType.batteryLow   => Icons.battery_alert_rounded,
    AlertType.fault        => Icons.error_outline_rounded,
  };
}

class AlertsService {
  static final AlertsService instance = AlertsService._();
  AlertsService._();

  final List<AlertEntry> _active = [];
  final Map<TirePosition, SensorPacket> _last = {};
  final _ctrl = StreamController<void>.broadcast();

  Stream<void> get changes => _ctrl.stream;
  List<AlertEntry> get active => List.unmodifiable(_active);
  int get count => _active.length;

  void init() {
    BleService.instance.packets.listen(_onPacket);
    SensorStore.instance.changes.listen((_) => _pruneUnpaired());
    VehicleService.instance.changes.listen((_) => _pruneUnpaired());
    LimitsService.instance.changes.listen((_) => _reEvaluateAll());
    // Pick up any readings cached by native background scanner so the alerts
    // section shows the correct state immediately when the app opens.
    for (final packet in BleService.instance.latest.values) {
      _onPacket(packet);
    }
  }

  // ── packet handler ──────────────────────────────────────────────────────────

  void _onPacket(SensorPacket packet) {
    final pos = _positionOf(packet.mac);
    if (pos == null) return;

    _last[pos] = packet;
    _active.removeWhere((a) => a.pos == pos);
    _evaluate(pos, packet);
    _ctrl.add(null);
  }

  // ── limits changed → re-score every known position ─────────────────────────

  void _reEvaluateAll() {
    _active.clear();
    for (final e in _last.entries) {
      _evaluate(e.key, e.value);
    }
    _ctrl.add(null);
  }

  // ── core evaluation ─────────────────────────────────────────────────────────

  void _evaluate(TirePosition pos, SensorPacket p) {
    final lim = LimitsService.instance;
    final now = DateTime.now();

    if (lim.pressureAlarmOn) {
      if (p.pressureBar < lim.minPressureBar) {
        _active.add(AlertEntry(
          pos: pos,
          type: AlertType.lowPressure,
          message: '${pos.label} — low pressure',
          detail:
              '${p.pressureBar.toStringAsFixed(2)} bar  ·  min ${lim.minPressureBar.toStringAsFixed(1)} bar',
          timestamp: now,
        ));
      } else if (p.pressureBar > lim.maxPressureBar) {
        _active.add(AlertEntry(
          pos: pos,
          type: AlertType.highPressure,
          message: '${pos.label} — high pressure',
          detail:
              '${p.pressureBar.toStringAsFixed(2)} bar  ·  max ${lim.maxPressureBar.toStringAsFixed(1)} bar',
          timestamp: now,
        ));
      }
    }

    if (lim.tempAlarmOn && p.temperatureC > lim.maxTempC) {
      _active.add(AlertEntry(
        pos: pos,
        type: AlertType.highTemp,
        message: '${pos.label} — high temperature',
        detail: '${p.temperatureC}°C  ·  limit ${lim.maxTempC}°C',
        timestamp: now,
      ));
    }

    if (lim.batteryAlarmOn && p.batteryLow) {
      _active.add(AlertEntry(
        pos: pos,
        type: AlertType.batteryLow,
        message: '${pos.label} — battery low',
        detail: 'Replace the sensor battery',
        timestamp: now,
      ));
    }

    if (p.hasFault) {
      _active.add(AlertEntry(
        pos: pos,
        type: AlertType.fault,
        message: '${pos.label} — sensor fault',
        detail: 'Internal sensor error detected',
        timestamp: now,
      ));
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  TirePosition? _positionOf(String mac) {
    for (final e in SensorStore.instance.pairedMacs.entries) {
      if (e.value == mac) return e.key;
    }
    for (final vehicle in VehicleService.instance.vehicles) {
      for (final e in VehicleService.instance.getPairedMacs(vehicle.id).entries) {
        if (e.value == mac) return e.key;
      }
    }
    return null;
  }

  Set<TirePosition> _allPairedPositions() {
    final result = <TirePosition>{};
    result.addAll(SensorStore.instance.pairedMacs.keys);
    for (final vehicle in VehicleService.instance.vehicles) {
      result.addAll(VehicleService.instance.getPairedMacs(vehicle.id).keys);
    }
    return result;
  }

  void _pruneUnpaired() {
    final paired = _allPairedPositions();
    _last.removeWhere((pos, _) => !paired.contains(pos));
    _active.removeWhere((a) => !paired.contains(a.pos));
    _ctrl.add(null);
  }

  void clearAll() {
    _active.clear();
    _ctrl.add(null);
  }
}
