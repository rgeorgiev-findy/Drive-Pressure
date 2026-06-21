import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/glass.dart';

class PairBleScreen extends StatelessWidget {
  const PairBleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusRow(),
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 26, 0),
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
                          Text('PAIRING WHEEL', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
                          const SizedBox(height: 2),
                          Text('Rear Right', style: AppText.chakra(size: 20, color: AppColors.text)),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.cyan.withOpacity(0.12),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.bluetooth_rounded, color: AppColors.cyan, size: 18),
                    ),
                  ],
                ),
              ),
              // instruction
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.cyan.withOpacity(0.06),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.22)),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: AppText.mono(size: 12, color: const Color(0xFFBCD2DF)),
                      children: [
                        const TextSpan(text: 'Change the pressure by '),
                        TextSpan(text: '0.1 bar', style: AppText.mono(size: 12, color: AppColors.cyan)),
                        const TextSpan(text: ', or hold the '),
                        TextSpan(text: 'LF transmitter', style: AppText.mono(size: 12, color: AppColors.cyan)),
                        const TextSpan(text: ' close to the phone to select your tire.'),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DETECTED TRANSMITTERS', style: AppText.mono(size: 10, color: AppColors.dimmer, spacing: 2)),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.cyan)),
                        const SizedBox(width: 7),
                        Text('SCANNING', style: AppText.mono(size: 10, color: AppColors.cyan)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
                  children: [
                    _transmitter(
                      context,
                      mac: 'C4:7B:8A:12:9F:3E',
                      rssi: '−42 dBm · nearest',
                      pressure: '2.3',
                      temp: '24',
                      bars: 4,
                      primary: true,
                    ),
                    const SizedBox(height: 12),
                    _transmitter(
                      context,
                      mac: 'A1:2F:5C:90:7D:B4',
                      rssi: '−71 dBm',
                      pressure: '2.5',
                      temp: '26',
                      bars: 2,
                      primary: false,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.14)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Enter MAC manually', style: AppText.chakra(size: 13, color: AppColors.dim, spacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transmitter(
    BuildContext context, {
    required String mac,
    required String rssi,
    required String pressure,
    required String temp,
    required int bars,
    required bool primary,
  }) {
    final accent = primary ? AppColors.cyan : AppColors.textSoft;
    return GlassCard(
      border: primary ? AppColors.cyan.withOpacity(0.45) : Colors.white.withOpacity(0.12),
      fill: Colors.white.withOpacity(primary ? 0.08 : 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: primary ? AppColors.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.06),
                ),
                child: Icon(Icons.bluetooth_rounded, color: primary ? AppColors.cyan : AppColors.dim, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mac, style: AppText.mono(size: 13, color: primary ? AppColors.text : AppColors.textSoft)),
                    const SizedBox(height: 2),
                    Text(rssi, style: AppText.mono(size: 10, color: primary ? AppColors.cyan : AppColors.dimmer)),
                  ],
                ),
              ),
              _signalBars(bars),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat('PRESSURE', pressure, 'bar', primary ? AppColors.cyan : AppColors.textSoft)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('TEMP', temp, '°C', AppColors.textSoft)),
              const SizedBox(width: 8),
              _selectButton(primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signalBars(int active) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final on = i < active;
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: 4,
          height: 4.0 + i * 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: on ? AppColors.cyan : AppColors.muted.withOpacity(0.6),
          ),
        );
      }),
    );
  }

  Widget _miniStat(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.mono(size: 9, color: AppColors.dimmer, spacing: 1)),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: value, style: AppText.chakra(size: 16, color: color)),
              TextSpan(text: ' $unit', style: AppText.mono(size: 10, color: AppColors.dimmer)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _selectButton(bool primary) {
    if (primary) {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cyanBright, AppColors.cyanDark],
          ),
        ),
        child: Center(child: Text('SELECT', style: AppText.chakra(size: 12, weight: FontWeight.w700, color: AppColors.ink, spacing: 1))),
      );
    }
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Center(child: Text('SELECT', style: AppText.chakra(size: 12, color: AppColors.textSoft, spacing: 1))),
    );
  }
}
