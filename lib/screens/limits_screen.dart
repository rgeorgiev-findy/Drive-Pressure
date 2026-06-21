import 'package:flutter/material.dart';
import '../services/limits_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';

class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  // Mirror LimitsService values locally for immediate UI feedback
  late double _minP;
  late double _maxP;
  late int    _maxT;
  late bool   _alarmP;
  late bool   _alarmT;
  late bool   _alarmB;

  @override
  void initState() {
    super.initState();
    final lim = LimitsService.instance;
    _minP   = lim.minPressureBar;
    _maxP   = lim.maxPressureBar;
    _maxT   = lim.maxTempC;
    _alarmP = lim.pressureAlarmOn;
    _alarmT = lim.tempAlarmOn;
    _alarmB = lim.batteryAlarmOn;
  }

  // Each change immediately persists and updates the service
  void _setMinP(double v) {
    setState(() => _minP = v);
    LimitsService.instance.setMinPressure(v);
  }

  void _setMaxP(double v) {
    setState(() => _maxP = v);
    LimitsService.instance.setMaxPressure(v);
  }

  void _setMaxT(int v) {
    setState(() => _maxT = v);
    LimitsService.instance.setMaxTemp(v);
  }

  void _setAlarmP(bool v) {
    setState(() => _alarmP = v);
    LimitsService.instance.setPressureAlarm(v);
  }

  void _setAlarmT(bool v) {
    setState(() => _alarmT = v);
    LimitsService.instance.setTempAlarm(v);
  }

  void _setAlarmB(bool v) {
    setState(() => _alarmB = v);
    LimitsService.instance.setBatteryAlarm(v);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALARM CONFIG',
                      style: AppText.mono(
                          size: 10, color: AppColors.dimmer, spacing: 2)),
                  const SizedBox(height: 2),
                  Text('Limits',
                      style: AppText.chakra(size: 24, color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  _sectionLabel('PRESSURE · BAR'),
                  Row(
                    children: [
                      Expanded(
                        child: _stepperBox(
                          'MIN · low alarm',
                          AppColors.redText,
                          _minP.toStringAsFixed(1),
                          () => _setMinP(
                              (_minP - 0.1).clamp(0.5, _maxP - 0.2)),
                          () => _setMinP(
                              (_minP + 0.1).clamp(0.5, _maxP - 0.2)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _stepperBox(
                          'MAX · high alarm',
                          AppColors.amber,
                          _maxP.toStringAsFixed(1),
                          () => _setMaxP(
                              (_maxP - 0.1).clamp(_minP + 0.2, 10.0)),
                          () => _setMaxP(
                              (_maxP + 0.1).clamp(_minP + 0.2, 10.0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('TEMPERATURE · °C'),
                  _tempRow(),
                  const SizedBox(height: 20),
                  _sectionLabel('ENABLED ALARMS'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.04),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _toggleRow('Low / high pressure', _alarmP,
                            _setAlarmP, divider: true),
                        _toggleRow('High temperature', _alarmT, _setAlarmT,
                            divider: true),
                        _toggleRow(
                            'Sensor battery low', _alarmB, _setAlarmB),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Auto-saved indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 14,
                          color: AppColors.green.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text('Changes saved automatically',
                          style: AppText.mono(
                              size: 11, color: AppColors.dimmer)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── widgets ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(t,
            style: AppText.mono(
                size: 10, color: AppColors.dimmer, spacing: 2)),
      );

  Widget _stepperBox(String label, Color labelColor, String value,
      VoidCallback onMinus, VoidCallback onPlus) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.mono(size: 10, color: labelColor)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundBtn(Icons.remove, false, onMinus),
              Text(value,
                  style: AppText.chakra(
                      size: 22,
                      weight: FontWeight.w700,
                      color: AppColors.text)),
              _roundBtn(Icons.add, true, onPlus),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tempRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Max temperature',
                    style:
                        AppText.chakra(size: 14, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('high-heat alarm above this',
                    style:
                        AppText.mono(size: 10, color: AppColors.amber)),
              ],
            ),
          ),
          _roundBtn(Icons.remove, false,
              () => _setMaxT((_maxT - 1).clamp(40, 120))),
          const SizedBox(width: 12),
          Text('$_maxT',
              style: AppText.chakra(
                  size: 22,
                  weight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(width: 12),
          _roundBtn(
              Icons.add, true, () => _setMaxT((_maxT + 1).clamp(40, 120))),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, bool accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: accent
              ? AppColors.cyan.withOpacity(0.16)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
              color: accent
                  ? AppColors.cyan.withOpacity(0.4)
                  : Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon,
            size: 18,
            color: accent ? AppColors.cyan : AppColors.text),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged,
      {bool divider = false}) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(
                  bottom:
                      BorderSide(color: Colors.white.withOpacity(0.06))))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: AppText.chakra(
                    size: 14,
                    weight: FontWeight.w500,
                    color: value
                        ? AppColors.text
                        : AppColors.textSoft)),
          ),
          _pillToggle(value, () => onChanged(!value)),
        ],
      ),
    );
  }

  Widget _pillToggle(bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? AppColors.cyan : Colors.white.withOpacity(0.12),
          boxShadow: value
              ? [
                  BoxShadow(
                      color: AppColors.cyan.withOpacity(0.35),
                      blurRadius: 8)
                ]
              : [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AppColors.ink : AppColors.dim,
            ),
          ),
        ),
      ),
    );
  }
}
