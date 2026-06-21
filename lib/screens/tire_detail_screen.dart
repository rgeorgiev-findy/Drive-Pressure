import 'dart:async';
import 'package:flutter/material.dart';
import '../models/tire_sensor.dart';
import '../services/ble_service.dart';
import '../services/sensor_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/status_row.dart';
import '../widgets/glass.dart';
import '../widgets/gauge_ring.dart';
import '../widgets/buttons.dart';
import '../widgets/mini_trend.dart';
import 'pair_ble_screen.dart';
import '../services/limits_service.dart';
import '../services/trend_service.dart';

class TireDetailScreen extends StatefulWidget {
  final TirePosition position;
  final SensorPacket? sensor;

  const TireDetailScreen({
    super.key,
    required this.position,
    required this.sensor,
  });

  @override
  State<TireDetailScreen> createState() => _TireDetailScreenState();
}

class _TireDetailScreenState extends State<TireDetailScreen> {
  late SensorPacket _current;
  bool _hasData = false;
  StreamSubscription<SensorPacket>? _bleSub;
  StreamSubscription<TirePosition>? _trendSub;

  List<double> get _pressureTrend =>
      TrendService.instance.pressure[widget.position] ?? [];
  List<double> get _tempTrend =>
      TrendService.instance.temp[widget.position] ?? [];

  @override
  void initState() {
    super.initState();
    if (widget.sensor != null) {
      _current = widget.sensor!;
      _hasData = true;
    }
    _bleSub = BleService.instance.packets.listen(_onPacket);
    // Redraw whenever TrendService adds a new point for our position
    _trendSub = TrendService.instance.updates.listen((pos) {
      if (pos == widget.position && mounted) setState(() {});
    });
  }

  void _onPacket(SensorPacket packet) {
    final targetMac = SensorStore.instance.pairedMacs[widget.position]
        ?? widget.sensor?.mac;
    if (targetMac == null || packet.mac != targetMac) return;
    if (!mounted) return;
    setState(() {
      _current = packet;
      _hasData = true;
    });
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _trendSub?.cancel();
    super.dispose();
  }

  bool get _isLow => _hasData &&
      _current.pressureBar < LimitsService.instance.minPressureBar;

  @override
  Widget build(BuildContext context) {
    if (!_hasData) return _buildNoData(context);

    final pos = widget.position;
    final pressure = _current.pressureBar;
    final fraction = (pressure / 3.5).clamp(0.0, 1.0);
    final gaugeColor = _isLow ? AppColors.red : AppColors.cyan;
    final sinceStr = _secondsSince(_current.timestamp);

    return Scaffold(
      body: AppBackground(
        glow: _isLow ? AppColors.red : AppColors.cyan,
        child: SafeArea(
          child: Column(
            children: [
              const StatusRow(),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 26, 8),
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
                          Text('WHEEL · ${pos.shortLabel}',
                              style: AppText.mono(
                                  size: 10, color: AppColors.dimmer, spacing: 2)),
                          const SizedBox(height: 2),
                          Text(pos.label,
                              style: AppText.chakra(size: 19, color: AppColors.text)),
                        ],
                      ),
                    ),
                    if (_isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppColors.red.withOpacity(0.5)),
                        ),
                        child: Text('LOW',
                            style: AppText.mono(
                                size: 10, color: AppColors.redText, spacing: 1)),
                      )
                    else if (_current.batteryLow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.amber.withOpacity(0.5)),
                        ),
                        child: Text('BATT',
                            style: AppText.mono(
                                size: 10, color: AppColors.amber, spacing: 1)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                  children: [
                    // Big pressure gauge
                    Center(
                      child: GaugeRing(
                        size: 164,
                        stroke: 12,
                        fraction: fraction,
                        color: gaugeColor,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pressure.toStringAsFixed(1),
                                style: AppText.chakra(
                                    size: 44,
                                    weight: FontWeight.w700,
                                    color: _isLow
                                        ? AppColors.redText
                                        : AppColors.text)),
                            Text('BAR',
                                style: AppText.mono(
                                    size: 10, color: AppColors.dimmer, spacing: 2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_isLow)
                      Center(
                        child: Text('BELOW SAFE THRESHOLD',
                            style: AppText.mono(
                                size: 11, color: const Color(0xFFB98792))),
                      ),
                    const SizedBox(height: 18),
                    // Mini stats row
                    Row(
                      children: [
                        _stat('TEMPERATURE', '${_current.temperatureC}°C',
                            AppColors.text),
                        const SizedBox(width: 10),
                        _stat('SIGNAL', '${_current.rssi} dBm', AppColors.cyan),
                        const SizedBox(width: 10),
                        _stat('FIRMWARE',
                            'v${_current.firmwareVersion}', AppColors.textSoft),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Info rows
                    GlassCard(
                      blur: false,
                      fill: Colors.white.withOpacity(0.04),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      child: Column(
                        children: [
                          _infoRow('MAC address', _current.mac, divider: true),
                          _infoRow('TX trigger', _triggerLabel(_current.txTrigger),
                              divider: true),
                          _infoRow('Last seen', sinceStr),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Live trend charts
                    GlassCard(
                      blur: false,
                      fill: Colors.white.withOpacity(0.04),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('LIVE TREND',
                                  style: AppText.mono(
                                      size: 10, color: AppColors.dimmer, spacing: 1)),
                              Text('${_pressureTrend.length} readings',
                                  style: AppText.mono(size: 10, color: AppColors.muted)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Pressure chart
                          Row(
                            children: [
                              _trendLabel('PRESSURE', '${pressure.toStringAsFixed(2)} bar', gaugeColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _pressureTrend.length > 1
                                    ? MiniTrend(color: gaugeColor, data: List.from(_pressureTrend))
                                    : _waitingLine(gaugeColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Temperature chart
                          Row(
                            children: [
                              _trendLabel('TEMP', '${_current.temperatureC}°C', AppColors.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _tempTrend.length > 1
                                    ? MiniTrend(color: AppColors.amber, data: List.from(_tempTrend))
                                    : _waitingLine(AppColors.amber),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: GhostButton(
                            'Replace sensor',
                            icon: Icons.bluetooth_searching_rounded,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PairBleScreen(
                                    tirePosition: widget.position),
                              ),
                            ),
                          ),
                        ),
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

  String _secondsSince(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds} sec ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours}h ago';
  }

  String _triggerLabel(TxTrigger t) {
    switch (t) {
      case TxTrigger.lf: return 'LF (reader)';
      case TxTrigger.deltaP: return 'ΔP (pressure change)';
      case TxTrigger.scheduled: return 'Scheduled';
      case TxTrigger.none: return 'None';
    }
  }

  Widget _trendLabel(String label, String value, Color color) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.mono(size: 9, color: AppColors.dimmer, spacing: 1)),
          const SizedBox(height: 3),
          Text(value, style: AppText.chakra(size: 13, color: color)),
        ],
      ),
    );
  }

  Widget _waitingLine(Color color) {
    return SizedBox(
      height: 64,
      child: Center(
        child: Text('Waiting for data…',
            style: AppText.mono(size: 10, color: color.withOpacity(0.4))),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: GlassCard(
        blur: false,
        fill: Colors.white.withOpacity(0.05),
        padding: const EdgeInsets.all(13),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppText.mono(size: 9, color: AppColors.dimmer, spacing: 1)),
            const SizedBox(height: 4),
            Text(value, style: AppText.chakra(size: 15, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String k, String v, {bool divider = false}) {
    return Container(
      decoration: divider
          ? BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.06))))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: AppText.mono(size: 11, color: AppColors.dimmer)),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.end,
                style: AppText.mono(size: 11, color: AppColors.textSoft)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData(BuildContext context) {
    final pos = widget.position;
    final mac = SensorStore.instance.pairedMacs[pos] ?? '—';

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 26, 8),
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
                          Text('WHEEL · ${pos.shortLabel}',
                              style: AppText.mono(
                                  size: 10, color: AppColors.dimmer, spacing: 2)),
                          const SizedBox(height: 2),
                          Text(pos.label,
                              style:
                                  AppText.chakra(size: 19, color: AppColors.text)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bluetooth_searching_rounded,
                        size: 56, color: AppColors.cyan.withOpacity(0.4)),
                    const SizedBox(height: 20),
                    Text('Waiting for sensor',
                        style: AppText.chakra(size: 17, color: AppColors.textSoft)),
                    const SizedBox(height: 8),
                    Text(mac,
                        style: AppText.mono(size: 12, color: AppColors.dimmer)),
                    const SizedBox(height: 6),
                    Text('No data received yet',
                        style: AppText.mono(size: 11, color: AppColors.muted)),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: GhostButton(
                        'Unpair sensor',
                        color: AppColors.redText,
                        icon: Icons.link_off_rounded,
                        onTap: () => _confirmDelete(context),
                      ),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete sensor?',
            style: AppText.chakra(size: 18, color: AppColors.text)),
        content: Text(
            '${widget.position.label} will be unpaired. You can add it again later.',
            style: AppText.sora(size: 13, color: AppColors.dim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: AppText.chakra(size: 13, color: AppColors.dim)),
          ),
          TextButton(
            onPressed: () async {
              await SensorStore.instance.removeSensor(widget.position);
              if (!mounted) return;
              Navigator.of(ctx).pop();
              Navigator.of(context).maybePop();
            },
            child: Text('Delete',
                style: AppText.chakra(size: 13, color: AppColors.redText)),
          ),
        ],
      ),
    );
  }
}
