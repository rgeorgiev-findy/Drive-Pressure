import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/glass.dart';
import '../widgets/gauge_ring.dart';
import '../widgets/buttons.dart';
import '../widgets/mini_trend.dart';

class TireDetailScreen extends StatelessWidget {
  const TireDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        glow: AppColors.red,
        child: SafeArea(
          child: Column(
            children: [
              const StatusRow(),
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 26, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.dim, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WHEEL · RL', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
                          const SizedBox(height: 2),
                          Text('Rear Left', style: AppText.chakra(size: 19, color: AppColors.text)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.red.withOpacity(0.5)),
                      ),
                      child: Text('LOW', style: AppText.mono(size: 10, color: AppColors.redText, spacing: 1)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                  children: [
                    // big gauge
                    Center(
                      child: GaugeRing(
                        size: 164,
                        stroke: 12,
                        fraction: 0.56,
                        color: AppColors.red,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('1.9', style: AppText.chakra(size: 44, weight: FontWeight.w700, color: AppColors.redText)),
                            Text('BAR', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('TARGET 2.2 BAR · −0.3 BELOW',
                          style: AppText.mono(size: 11, color: const Color(0xFFB98792))),
                    ),
                    const SizedBox(height: 18),
                    // mini stats
                    Row(
                      children: [
                        _stat('TEMPERATURE', '23°C', AppColors.text),
                        const SizedBox(width: 10),
                        _stat('SENSOR BATT.', '86%', AppColors.green),
                        const SizedBox(width: 10),
                        _stat('SIGNAL', '−42', AppColors.cyan, unit: 'dBm'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // info rows
                    GlassCard(
                      blur: false,
                      fill: Colors.white.withOpacity(0.04),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Column(
                        children: [
                          _infoRow('MAC address', 'C4:7B:8A:12:9F:3E', divider: true),
                          _infoRow('Firmware', 'v2.4.1', divider: true),
                          _infoRow('Last sync', '12 sec ago'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // trend
                    GlassCard(
                      blur: false,
                      fill: Colors.white.withOpacity(0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('24-HOUR TREND', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 1)),
                              Text('−0.4 BAR', style: AppText.mono(size: 10, color: AppColors.redText)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const MiniTrend(
                            color: AppColors.red,
                            data: [2.3, 2.28, 2.22, 2.16, 2.05, 1.99, 1.93, 1.9],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // actions
                    Row(
                      children: [
                        const Expanded(child: GhostButton('Replace sensor')),
                        const SizedBox(width: 10),
                        GhostButton(
                          'Delete',
                          expand: false,
                          color: AppColors.redText,
                          icon: Icons.delete_outline_rounded,
                          onTap: () => _confirmDelete(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color, {String? unit}) {
    return Expanded(
      child: GlassCard(
        blur: false,
        fill: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.all(13),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.mono(size: 9, color: AppColors.dimmer, spacing: 1)),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(children: [
                TextSpan(text: value, style: AppText.chakra(size: 17, color: color)),
                if (unit != null) TextSpan(text: ' $unit', style: AppText.mono(size: 9, color: AppColors.dimmer)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String k, String v, {bool divider = false}) {
    return Container(
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: AppText.mono(size: 11, color: AppColors.dimmer)),
          Text(v, style: AppText.mono(size: 11, color: AppColors.textSoft)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete sensor?', style: AppText.chakra(size: 18, color: AppColors.text)),
        content: Text('Rear Left will be unpaired. You can add it again later.',
            style: AppText.sora(size: 13, color: AppColors.dim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppText.chakra(size: 13, color: AppColors.dim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).maybePop();
            },
            child: Text('Delete', style: AppText.chakra(size: 13, color: AppColors.redText)),
          ),
        ],
      ),
    );
  }
}
