import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/buttons.dart';

class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  double minP = 2.0;
  double maxP = 2.8;
  int maxT = 70;
  bool pressureAlarm = true;
  bool tempAlarm = true;
  bool batteryAlarm = false;

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
                  Text('ALARM CONFIG', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
                  const SizedBox(height: 2),
                  Text('Limits', style: AppText.chakra(size: 24, color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                children: [
                  _sectionLabel('PRESSURE · BAR'),
                  Row(
                    children: [
                      Expanded(
                        child: _stepperBox(
                          'MIN · low alarm',
                          AppColors.redText,
                          minP.toStringAsFixed(1),
                          () => setState(() => minP = (minP - 0.1).clamp(1.0, maxP - 0.1)),
                          () => setState(() => minP = (minP + 0.1).clamp(1.0, maxP - 0.1)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _stepperBox(
                          'MAX · high alarm',
                          AppColors.amber,
                          maxP.toStringAsFixed(1),
                          () => setState(() => maxP = (maxP - 0.1).clamp(minP + 0.1, 4.0)),
                          () => setState(() => maxP = (maxP + 0.1).clamp(minP + 0.1, 4.0)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionLabel('TEMPERATURE · °C'),
                  _tempRow(),
                  const SizedBox(height: 18),
                  _sectionLabel('ENABLED ALARMS'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _toggleRow('Low / high pressure', pressureAlarm, (v) => setState(() => pressureAlarm = v), true),
                        _toggleRow('High temperature', tempAlarm, (v) => setState(() => tempAlarm = v), true),
                        _toggleRow('Sensor battery low', batteryAlarm, (v) => setState(() => batteryAlarm = v), false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  CyanButton('SAVE LIMITS', onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.panel,
                        content: Text('Limits saved', style: AppText.chakra(size: 13, color: AppColors.cyan)),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(t, style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
      );

  Widget _stepperBox(String label, Color labelColor, String value, VoidCallback onMinus, VoidCallback onPlus) {
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
              Text(value, style: AppText.chakra(size: 22, weight: FontWeight.w700, color: AppColors.text)),
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
                Text('Max temperature', style: AppText.chakra(size: 14, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('high-heat alarm above this', style: AppText.mono(size: 10, color: AppColors.amber)),
              ],
            ),
          ),
          _roundBtn(Icons.remove, false, () => setState(() => maxT = (maxT - 1).clamp(40, 120))),
          const SizedBox(width: 12),
          Text('$maxT', style: AppText.chakra(size: 22, weight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(width: 12),
          _roundBtn(Icons.add, true, () => setState(() => maxT = (maxT + 1).clamp(40, 120))),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, bool accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: accent ? AppColors.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.06),
          border: Border.all(color: accent ? AppColors.cyan.withOpacity(0.4) : Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, size: 16, color: accent ? AppColors.cyan : AppColors.text),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged, bool divider) {
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.chakra(size: 14, weight: FontWeight.w500, color: value ? AppColors.text : AppColors.textSoft)),
          _pillToggle(value, () => onChanged(!value)),
        ],
      ),
    );
  }

  Widget _pillToggle(bool value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? AppColors.cyan : Colors.white.withOpacity(0.12),
        ),
        child: Align(
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
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
