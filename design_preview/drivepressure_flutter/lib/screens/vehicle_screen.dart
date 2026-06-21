import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/tire_logo.dart';
import '../widgets/tire_slot.dart';

class VehicleScreen extends StatelessWidget {
  final VoidCallback onOpenTire;
  final VoidCallback onAddTire;
  const VehicleScreen({super.key, required this.onOpenTire, required this.onAddTire});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const StatusRow(),
            // header: logo left, alerts pill right
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
              child: Row(
                children: [
                  const TireLogo(size: 40),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: 'Drive', style: AppText.chakra(size: 17, color: AppColors.text, spacing: -0.3)),
                      TextSpan(text: 'Pressure', style: AppText.chakra(size: 17, color: AppColors.cyan, spacing: -0.3)),
                    ]),
                  ),
                  const Spacer(),
                  _pill('1 ALERT', AppColors.redText),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 340,
                  height: 392,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // car body
                      Container(
                        width: 120,
                        height: 272,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(58), bottom: Radius.circular(52)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.03)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                      ),
                      // windshield
                      Align(
                        alignment: const Alignment(0, -0.42),
                        child: Container(
                          width: 92,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(34), bottom: Radius.circular(14)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AppColors.cyan.withOpacity(0.16), AppColors.cyan.withOpacity(0.03)],
                            ),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                        ),
                      ),
                      // roof panel
                      Align(
                        alignment: const Alignment(0, 0.16),
                        child: Container(
                          width: 90,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        child: Text('FRONT', style: AppText.mono(size: 9, color: AppColors.muted, spacing: 3)),
                      ),
                      // wheels
                      const Positioned(
                        left: 0,
                        top: 50,
                        child: TireSlot(state: TireState.ok, value: '2.4', label: 'FL · 24°', fraction: 0.92),
                      ),
                      const Positioned(
                        right: 0,
                        top: 50,
                        child: TireSlot(state: TireState.ok, value: '2.3', label: 'FR · 25°', fraction: 0.90),
                      ),
                      Positioned(
                        left: 0,
                        bottom: 50,
                        child: TireSlot(
                            state: TireState.alert,
                            value: '1.9',
                            label: 'RL · 23°',
                            fraction: 0.56,
                            onTap: onOpenTire),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 50,
                        child: TireSlot(state: TireState.add, label: 'RR · ADD', onTap: onAddTire),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // alert strip
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.red.withOpacity(0.12),
                  border: Border.all(color: AppColors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.redText, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rear Left — low pressure', style: AppText.chakra(size: 13, color: AppColors.redText)),
                          Text('0.3 bar under target · inflate soon',
                              style: AppText.mono(size: 10, color: const Color(0xFFB98792))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.4)),
        ),
        child: Text(t, style: AppText.mono(size: 11, color: c)),
      );
}
