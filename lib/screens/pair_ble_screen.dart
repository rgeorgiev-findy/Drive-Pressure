import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tire_sensor.dart';
import '../services/ble_service.dart';
import '../services/sensor_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/glass.dart';

class PairBleScreen extends StatefulWidget {
  final TirePosition tirePosition;

  const PairBleScreen({super.key, required this.tirePosition});

  @override
  State<PairBleScreen> createState() => _PairBleScreenState();
}

class _PairBleScreenState extends State<PairBleScreen> {
  // Only show sensors triggered by LF or DeltaP (active pairing signal)
  final Map<String, SensorPacket> _candidates = {};
  StreamSubscription<SensorPacket>? _sub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() => _scanning = true);
    _sub = BleService.instance.packets.listen(_onPacket);
    await BleService.instance.startScan();
  }

  void _onPacket(SensorPacket packet) {
    if (!packet.isPairingCandidate) return;
    if (!mounted) return;
    setState(() => _candidates[packet.mac] = packet);
  }

  Future<void> _selectSensor(SensorPacket packet) async {
    await SensorStore.instance.saveSensor(widget.tirePosition, packet.mac);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posLabel = widget.tirePosition.label;
    final posShort = widget.tirePosition.shortLabel;
    final sorted = _candidates.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusRow(),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 26, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.dim, size: 20),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PAIRING · $posShort',
                              style: AppText.mono(
                                  size: 10, color: AppColors.dimmer, spacing: 2)),
                          const SizedBox(height: 2),
                          Text(posLabel,
                              style: AppText.chakra(size: 20, color: AppColors.text)),
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
                      child: const Icon(Icons.bluetooth_rounded,
                          color: AppColors.cyan, size: 18),
                    ),
                  ],
                ),
              ),
              // Instruction banner
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
                        const TextSpan(text: 'Inflate or deflate the tire by '),
                        TextSpan(
                            text: '0.1 bar',
                            style: AppText.mono(size: 12, color: AppColors.cyan)),
                        const TextSpan(text: ', or bring the '),
                        TextSpan(
                            text: 'LF transmitter',
                            style: AppText.mono(size: 12, color: AppColors.cyan)),
                        const TextSpan(text: ' close to the tire.'),
                      ],
                    ),
                  ),
                ),
              ),
              // Scanning label
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DETECTED TRANSMITTERS',
                        style: AppText.mono(
                            size: 10, color: AppColors.dimmer, spacing: 2)),
                    Row(
                      children: [
                        _ScanDot(active: _scanning),
                        const SizedBox(width: 7),
                        Text('SCANNING',
                            style: AppText.mono(size: 10, color: AppColors.cyan)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(26, 0, 26, 16),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _SensorTile(packet: sorted[i], onSelect: _selectSensor),
                      ),
              ),
              // Manual entry fallback
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _enterMacManually,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.14)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Enter MAC manually',
                        style: AppText.chakra(
                            size: 13, color: AppColors.dim, spacing: 1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_searching_rounded,
              color: AppColors.cyan.withOpacity(0.4), size: 48),
          const SizedBox(height: 16),
          Text('Waiting for triggered sensors…',
              style: AppText.chakra(size: 14, color: AppColors.dimmer)),
          const SizedBox(height: 6),
          Text('Press the valve or bring the LF reader close',
              style: AppText.mono(size: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  void _enterMacManually() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('Enter MAC address',
            style: AppText.chakra(size: 16, color: AppColors.text)),
        content: TextField(
          controller: controller,
          style: AppText.mono(size: 14, color: AppColors.text),
          decoration: InputDecoration(
            hintText: 'AA:BB:CC:DD:EE:FF',
            hintStyle: AppText.mono(size: 13, color: AppColors.dimmer),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.cyan)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.cyan, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: AppText.chakra(size: 13, color: AppColors.dimmer)),
          ),
          TextButton(
            onPressed: () async {
              final mac = controller.text.trim().toUpperCase();
              if (mac.length == 17) {
                await SensorStore.instance.saveSensor(widget.tirePosition, mac);
                if (mounted) Navigator.of(context)
                  ..pop()
                  ..pop();
              }
            },
            child:
                Text('SAVE', style: AppText.chakra(size: 13, color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }
}

// ── Individual sensor tile ──────────────────────────────────────────────────

class _SensorTile extends StatelessWidget {
  final SensorPacket packet;
  final Future<void> Function(SensorPacket) onSelect;

  const _SensorTile({required this.packet, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isLf = packet.txTrigger == TxTrigger.lf;
    final triggerLabel = isLf ? 'LF TRIGGERED' : 'Δ PRESSURE';
    final bars = _rssiToBars(packet.rssi);

    return GlassCard(
      border: AppColors.cyan.withOpacity(0.45),
      fill: Colors.white.withOpacity(0.08),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: AppColors.cyan.withOpacity(0.16),
                ),
                child: const Icon(Icons.bluetooth_rounded,
                    color: AppColors.cyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(packet.mac,
                        style: AppText.mono(size: 13, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text('${packet.rssi} dBm · $triggerLabel',
                        style: AppText.mono(size: 10, color: AppColors.cyan)),
                  ],
                ),
              ),
              _SignalBars(count: bars),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _miniStat('PRESSURE',
                      packet.pressureBar.toStringAsFixed(2), 'bar',
                      AppColors.cyan)),
              const SizedBox(width: 8),
              Expanded(
                  child: _miniStat(
                      'TEMP', '${packet.temperatureC}', '°C', AppColors.textSoft)),
              const SizedBox(width: 8),
              _SelectButton(onTap: () => onSelect(packet)),
            ],
          ),
        ],
      ),
    );
  }

  int _rssiToBars(int rssi) {
    if (rssi >= -55) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -75) return 2;
    return 1;
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
          Text(label,
              style: AppText.mono(size: 9, color: AppColors.dimmer, spacing: 1)),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: value, style: AppText.chakra(size: 16, color: color)),
              TextSpan(
                  text: ' $unit',
                  style: AppText.mono(size: 10, color: AppColors.dimmer)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SelectButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SelectButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Center(
          child: Text('SELECT',
              style: AppText.chakra(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                  spacing: 1)),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int count;
  const _SignalBars({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final on = i < count;
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
}

// Pulsing dot while scanning
class _ScanDot extends StatefulWidget {
  final bool active;
  const _ScanDot({required this.active});

  @override
  State<_ScanDot> createState() => _ScanDotState();
}

class _ScanDotState extends State<_ScanDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: AppColors.cyan),
      ),
    );
  }
}
