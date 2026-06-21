import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';

enum AlarmSeverity { critical, warning, resolved }

class _Alarm {
  final AlarmSeverity sev;
  final IconData icon;
  final String title;
  final String detail;
  final String time;
  const _Alarm(this.sev, this.icon, this.title, this.detail, this.time);
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const _active = [
    _Alarm(AlarmSeverity.critical, Icons.warning_amber_rounded, 'Low pressure',
        'Rear Left · 1.9 bar (target 2.2)', '2 min'),
    _Alarm(AlarmSeverity.warning, Icons.thermostat_rounded, 'High temperature',
        'Front Right · 71°C (limit 70)', '1 hr'),
  ];
  static const _resolved = [
    _Alarm(AlarmSeverity.resolved, Icons.check_rounded, 'Sensor battery low', 'Rear Right · replaced', 'Yesterday'),
    _Alarm(AlarmSeverity.resolved, Icons.check_rounded, 'Signal lost', 'Front Left · reconnected', '2 days'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      glow: AppColors.red,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VOLVO XC60', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
                      const SizedBox(height: 2),
                      Text('Alerts', style: AppText.chakra(size: 24, color: AppColors.text)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.red.withOpacity(0.4)),
                    ),
                    child: Text('2 ACTIVE', style: AppText.mono(size: 11, color: AppColors.redText)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: [
                  _label('ACTIVE'),
                  for (final a in _active) _tile(a),
                  const SizedBox(height: 8),
                  _label('RESOLVED'),
                  for (final a in _resolved) _tile(a),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(t, style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
      );

  Widget _tile(_Alarm a) {
    final Color c = switch (a.sev) {
      AlarmSeverity.critical => AppColors.red,
      AlarmSeverity.warning => AppColors.amber,
      AlarmSeverity.resolved => AppColors.muted,
    };
    final Color title = switch (a.sev) {
      AlarmSeverity.critical => AppColors.redText,
      AlarmSeverity.warning => AppColors.amber,
      AlarmSeverity.resolved => AppColors.textSoft,
    };
    final bool resolved = a.sev == AlarmSeverity.resolved;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: resolved ? Colors.white.withOpacity(0.04) : c.withOpacity(0.08),
        border: Border.all(color: resolved ? Colors.white.withOpacity(0.09) : c.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: c)),
          const SizedBox(width: 13),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: c.withOpacity(0.16)),
            child: Icon(a.icon, size: 17, color: resolved ? AppColors.dim : title),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(a.title, style: AppText.chakra(size: 14, color: title)),
                    Text(a.time, style: AppText.mono(size: 10, color: resolved ? AppColors.dimmer : AppColors.dim)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(a.detail, style: AppText.mono(size: 11, color: resolved ? AppColors.dim : const Color(0xFFBCD2DF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
