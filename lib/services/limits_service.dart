import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class LimitsService {
  static final LimitsService instance = LimitsService._();
  LimitsService._();

  static const _kMinP    = 'lim_min_pressure';
  static const _kMaxP    = 'lim_max_pressure';
  static const _kMaxT    = 'lim_max_temp';
  static const _kAlarmP  = 'lim_alarm_pressure';
  static const _kAlarmT  = 'lim_alarm_temp';
  static const _kAlarmB  = 'lim_alarm_battery';

  final _ctrl = StreamController<void>.broadcast();
  Stream<void> get changes => _ctrl.stream;

  // Defaults
  double minPressureBar    = 2.0;
  double maxPressureBar    = 2.8;
  int    maxTempC          = 70;
  bool   pressureAlarmOn   = true;
  bool   tempAlarmOn       = true;
  bool   batteryAlarmOn    = true;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    minPressureBar  = _prefs!.getDouble(_kMinP)  ?? 2.0;
    maxPressureBar  = _prefs!.getDouble(_kMaxP)  ?? 2.8;
    maxTempC        = _prefs!.getInt(_kMaxT)     ?? 70;
    pressureAlarmOn = _prefs!.getBool(_kAlarmP)  ?? true;
    tempAlarmOn     = _prefs!.getBool(_kAlarmT)  ?? true;
    batteryAlarmOn  = _prefs!.getBool(_kAlarmB)  ?? true;
  }

  Future<void> _persist() async {
    await _prefs?.setDouble(_kMinP,   minPressureBar);
    await _prefs?.setDouble(_kMaxP,   maxPressureBar);
    await _prefs?.setInt(_kMaxT,      maxTempC);
    await _prefs?.setBool(_kAlarmP,   pressureAlarmOn);
    await _prefs?.setBool(_kAlarmT,   tempAlarmOn);
    await _prefs?.setBool(_kAlarmB,   batteryAlarmOn);
    _ctrl.add(null);
  }

  void setMinPressure(double v)   { minPressureBar  = v; _persist(); }
  void setMaxPressure(double v)   { maxPressureBar  = v; _persist(); }
  void setMaxTemp(int v)          { maxTempC        = v; _persist(); }
  void setPressureAlarm(bool v)   { pressureAlarmOn = v; _persist(); }
  void setTempAlarm(bool v)       { tempAlarmOn     = v; _persist(); }
  void setBatteryAlarm(bool v)    { batteryAlarmOn  = v; _persist(); }
}
