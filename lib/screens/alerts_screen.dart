import 'dart:async';
import 'package:flutter/material.dart';
import '../services/alerts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AlertsService.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _clearAll() {
    final count = AlertsService.instance.count;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Clear all alerts?',
            style: AppText.chakra(size: 17, color: AppColors.text)),
        content: Text(
            'This will dismiss all $count active alert${count == 1 ? '' : 's'}.',
            style: AppText.sora(size: 13, color: AppColors.dim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppText.chakra(size: 13, color: AppColors.dim)),
          ),
          TextButton(
            onPressed: () {
              AlertsService.instance.clearAll();
              Navigator.pop(ctx);
            },
            child: Text('Clear all',
                style: AppText.chakra(size: 13, color: AppColors.redText)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarms = AlertsService.instance.active;

    return AppBackground(
      glow: alarms.isEmpty ? AppColors.cyan : AppColors.red,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACTIVE ALARMS',
                          style: AppText.mono(
                              size: 10, color: AppColors.dimmer, spacing: 2)),
                      const SizedBox(height: 2),
                      Text('Alerts',
                          style: AppText.chakra(size: 24, color: AppColors.text)),
                    ],
                  ),
                  if (alarms.isNotEmpty)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.red.withOpacity(0.4)),
                          ),
                          child: Text('${alarms.length} ACTIVE',
                              style: AppText.mono(
                                  size: 11, color: AppColors.redText)),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _clearAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.06),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.clear_all_rounded,
                                    size: 14, color: AppColors.dim),
                                const SizedBox(width: 5),
                                Text('CLEAR',
                                    style: AppText.mono(
                                        size: 11, color: AppColors.dim)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: alarms.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      children: alarms.map(_tile).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: AppColors.green.withOpacity(0.5), size: 52),
          const SizedBox(height: 16),
          Text('All clear',
              style: AppText.chakra(size: 16, color: AppColors.textSoft)),
          const SizedBox(height: 6),
          Text('No active alarms at this moment',
              style: AppText.mono(size: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _tile(AlertEntry a) {
    final Color c = a.severity == AlertSeverity.critical
        ? AppColors.red
        : AppColors.amber;
    final Color titleColor = a.severity == AlertSeverity.critical
        ? AppColors.redText
        : AppColors.amber;
    final timeStr = _relativeTime(a.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: c.withOpacity(0.08),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3), color: c)),
          const SizedBox(width: 13),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: c.withOpacity(0.16)),
            child: Icon(a.icon, size: 17, color: titleColor),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(a.message,
                        style: AppText.chakra(size: 13, color: titleColor)),
                    Text(timeStr,
                        style: AppText.mono(size: 10, color: AppColors.dim)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(a.detail,
                    style: AppText.mono(
                        size: 11, color: const Color(0xFFBCD2DF))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }
}
