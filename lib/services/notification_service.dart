import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'alerts_service.dart';
import 'vehicle_service.dart';
import '../models/tire_sensor.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _notified = <String>{};  // tracks alert keys already notified this session
  bool _ready = false;

  Future<void> init() async {
    if (!Platform.isIOS) return;

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Show banners even when the app is in the foreground
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    await _plugin.initialize(
      const InitializationSettings(iOS: iosSettings),
    );
    _ready = true;

    // Listen for new alerts and fire notifications
    AlertsService.instance.changes.listen((_) => _onAlertsChanged());
    _onAlertsChanged();
  }

  void _onAlertsChanged() {
    if (!_ready) return;
    for (final alert in AlertsService.instance.active) {
      final key = '${alert.pos.name}:${alert.type.name}';
      if (_notified.contains(key)) continue;
      _notified.add(key);
      _fire(alert);
    }
    // Remove keys for resolved alerts so they re-trigger if alarm comes back
    final activeKeys = AlertsService.instance.active
        .map((a) => '${a.pos.name}:${a.type.name}')
        .toSet();
    _notified.removeWhere((k) => !activeKeys.contains(k));
  }

  Future<void> _fire(AlertEntry alert) async {
    final vehicleName = _vehicleNameFor(alert.pos);
    final title = vehicleName != null
        ? '$vehicleName — ${alert.pos.shortLabel}'
        : alert.pos.label;

    await _plugin.show(
      alert.pos.index * 10 + alert.type.index,
      title,
      alert.message.replaceFirst('${alert.pos.label} — ', ''),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  /// Find the vehicle name that has the given tire position paired.
  String? _vehicleNameFor(TirePosition pos) {
    final vs = VehicleService.instance;
    for (final v in [...(vs.activeCar != null ? [vs.activeCar!] : []),
                     ...(vs.activeTrailer != null ? [vs.activeTrailer!] : []),
                     ...vs.cars, ...vs.trailers]) {
      final macs = vs.getPairedMacs(v.id);
      if (macs.containsKey(pos)) return v.name;
    }
    return null;
  }
}
