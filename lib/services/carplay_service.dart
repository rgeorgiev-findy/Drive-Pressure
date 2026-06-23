import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_carplay/flutter_carplay.dart';

import '../models/tire_sensor.dart';
import 'ble_service.dart';
import 'limits_service.dart';
import 'trend_service.dart';
import 'vehicle_service.dart';

class CarPlayService {
  static final CarPlayService instance = CarPlayService._();
  CarPlayService._();

  static const _rootId = 'findytpms_root';

  FlutterCarplay? _fcp;
  StreamSubscription? _trendSub;
  StreamSubscription? _vehicleSub;
  Timer? _debounce;

  // "posName_pressure" / "posName_temp" → file:// path (null = not enough data)
  final Map<String, String?> _chartCache = {};

  void init() {
    if (!Platform.isIOS) return;
    _fcp = FlutterCarplay();
    _fcp!.addListenerOnConnectionChange((status) {
      if (status == ConnectionStatusTypes.connected) _setRoot();
    });
    _setRoot();
    _vehicleSub = VehicleService.instance.changes.listen((_) {
      _chartCache.clear();
      _setRoot();
    });
    _trendSub = TrendService.instance.updates.listen(_onTrend);
  }

  void _onTrend(TirePosition pos) {
    _chartCache.remove('${pos.name}_pressure');
    _chartCache.remove('${pos.name}_temp');
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _update);
  }

  Future<void> _setRoot() async {
    final sections = await _buildSections();
    await FlutterCarplay.setRootTemplate(
      rootTemplate: CPListTemplate(
        title: 'FindyTPMS',
        sections: sections,
        emptyViewTitleVariants: ['FindyTPMS'],
        emptyViewSubtitleVariants: ['No vehicles configured'],
        id: _rootId,
      ),
      animated: false,
    );
  }

  Future<void> _update() async {
    final sections = await _buildSections();
    await _fcp?.updateListTemplateSections(
      elementId: _rootId,
      sections: sections,
    );
  }

  // ─── Sections ────────────────────────────────────────────────────────────

  Future<List<CPListSection>> _buildSections() async {
    final vs = VehicleService.instance;
    final car = vs.activeCar;
    final trailer = vs.activeTrailer;

    if (car == null && trailer == null) {
      return [
        CPListSection(items: [
          CPListItem(
            text: 'No vehicle selected',
            detailText: 'Open FindyTPMS and select a vehicle',
          ),
        ]),
      ];
    }

    final sections = <CPListSection>[];
    if (car != null) sections.add(await _vehicleSection(car, vs.getPairedMacs(car.id)));
    if (trailer != null) sections.add(await _vehicleSection(trailer, vs.getPairedMacs(trailer.id)));
    return sections;
  }

  Future<CPListSection> _vehicleSection(
    Vehicle vehicle,
    Map<TirePosition, String> macs,
  ) async {
    final items = <CPListItem>[];
    for (final pos in vehicle.type.positions) {
      items.add(await _tireItem(pos, macs[pos]));
    }
    return CPListSection(
      header: '${vehicle.name}  ·  ${vehicle.type.shortLabel}',
      items: items,
    );
  }

  Future<CPListItem> _tireItem(TirePosition pos, String? mac) async {
    final packet = mac != null ? BleService.instance.latest[mac] : null;
    final isLow = packet != null &&
        packet.pressureBar < LimitsService.instance.minPressureBar;

    // Generate sparklines — colours match the phone app theme
    final pChart = await _sparkline(pos, 'pressure', const ui.Color(0xFF34E3FF), 120, 44);
    final tChart = await _sparkline(pos, 'temp', const ui.Color(0xFFFFB02E), 80, 44);

    if (packet == null) {
      return CPListItem(
        text: '${pos.shortLabel}   No signal',
        detailText: pos.label,
        image: pChart,
        trailingImage: tChart,
      );
    }

    final pArrow = _arrow(TrendService.instance.pressure[pos] ?? []);
    final tArrow = _arrow(TrendService.instance.temp[pos] ?? []);

    return CPListItem(
      text: '${pos.shortLabel}   ${isLow ? "⚠ " : ""}'
          '${packet.pressureBar.toStringAsFixed(2)} bar  $pArrow',
      detailText: '${packet.temperatureC}°C  $tArrow',
      image: pChart,
      trailingImage: tChart,
    );
  }

  String _arrow(List<double> data) {
    if (data.length < 4) return '→';
    final tail = data.sublist(math.max(0, data.length - 5));
    final d = tail.last - tail.first;
    if (d > 0.05) return '↑';
    if (d < -0.05) return '↓';
    return '→';
  }

  // ─── Sparkline renderer ───────────────────────────────────────────────────

  Future<String?> _sparkline(
    TirePosition pos,
    String type,
    ui.Color color,
    double w,
    double h,
  ) async {
    final key = '${pos.name}_$type';
    if (_chartCache.containsKey(key)) return _chartCache[key];

    final raw = type == 'pressure'
        ? TrendService.instance.pressure[pos]
        : TrendService.instance.temp[pos];

    if (raw == null || raw.length < 2) {
      _chartCache[key] = null;
      return null;
    }

    final data = raw.length > 20 ? raw.sublist(raw.length - 20) : List<double>.from(raw);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w, h));

      // Background matches AppColors.bg (#08111C)
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, w, h),
          const ui.Radius.circular(6),
        ),
        ui.Paint()..color = const ui.Color(0xFF08111C),
      );

      final minV = data.reduce(math.min);
      final maxV = data.reduce(math.max);
      final range = maxV - minV;
      const pad = 6.0;

      double _x(int i) => pad + (i / (data.length - 1)) * (w - pad * 2);
      double _y(double v) => range < 0.001
          ? h / 2
          : (h - pad) - ((v - minV) / range) * (h - pad * 2);

      // Fill under curve
      final fill = ui.Path();
      fill.moveTo(_x(0), _y(data[0]));
      for (int i = 1; i < data.length; i++) fill.lineTo(_x(i), _y(data[i]));
      fill.lineTo(_x(data.length - 1), h - pad);
      fill.lineTo(_x(0), h - pad);
      fill.close();
      canvas.drawPath(
        fill,
        ui.Paint()
          ..color = ui.Color.fromARGB(38, color.red, color.green, color.blue)
          ..style = ui.PaintingStyle.fill,
      );

      // Sparkline
      final line = ui.Path();
      line.moveTo(_x(0), _y(data[0]));
      for (int i = 1; i < data.length; i++) line.lineTo(_x(i), _y(data[i]));
      canvas.drawPath(
        line,
        ui.Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round,
      );

      // End-point dot
      canvas.drawCircle(
        ui.Offset(_x(data.length - 1), _y(data.last)),
        3.0,
        ui.Paint()..color = color,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(w.toInt(), h.toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        _chartCache[key] = null;
        return null;
      }

      final file = File('${Directory.systemTemp.path}/ftp_${pos.name}_$type.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      final path = 'file://${file.path}';
      _chartCache[key] = path;
      return path;
    } catch (_) {
      _chartCache[key] = null;
      return null;
    }
  }

  void dispose() {
    _trendSub?.cancel();
    _vehicleSub?.cancel();
    _debounce?.cancel();
    _fcp?.closeConnection();
  }
}
