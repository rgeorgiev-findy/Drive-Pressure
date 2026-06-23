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

  FlutterCarplay? _fcp;
  StreamSubscription? _trendSub;
  StreamSubscription? _vehicleSub;
  Timer? _debounce;

  // tile cache: pos.name → file:// path (single combined image per tire)
  final Map<String, String?> _tileCache = {};

  void init() {
    if (!Platform.isIOS) return;
    _fcp = FlutterCarplay();
    _fcp!.addListenerOnConnectionChange((status) {
      if (status == ConnectionStatusTypes.connected) _setRoot();
    });
    _setRoot();
    _vehicleSub = VehicleService.instance.changes.listen((_) {
      _tileCache.clear();
      _setRoot();
    });
    _trendSub = TrendService.instance.updates.listen(_onTrend);
  }

  void _onTrend(TirePosition pos) {
    _tileCache.remove(pos.name);
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _setRoot);
  }

  Future<void> _setRoot() async {
    final vs = VehicleService.instance;
    final car = vs.activeCar;
    final trailer = vs.activeTrailer;

    CPTemplate root;

    if (car == null && trailer == null) {
      root = CPListTemplate(
        title: 'FindyTPMS',
        sections: [
          CPListSection(items: [
            CPListItem(
              text: 'No vehicle selected',
              detailText: 'Open FindyTPMS and select a vehicle',
            ),
          ]),
        ],
        emptyViewTitleVariants: ['FindyTPMS'],
        emptyViewSubtitleVariants: ['No vehicles configured'],
      );
    } else if (car != null && trailer != null) {
      final carGrid = await _gridForVehicle(
        car, vs.getPairedMacs(car.id), tabTitle: car.name,
      );
      final trailerGrid = await _gridForVehicle(
        trailer, vs.getPairedMacs(trailer.id), tabTitle: trailer.name,
      );
      root = CPTabBarTemplate(templates: [carGrid, trailerGrid]);
    } else {
      final v = car ?? trailer!;
      root = await _gridForVehicle(v, vs.getPairedMacs(v.id));
    }

    await FlutterCarplay.setRootTemplate(rootTemplate: root, animated: false);
  }

  // ─── Grid ─────────────────────────────────────────────────────────────────

  Future<CPGridTemplate> _gridForVehicle(
    Vehicle vehicle,
    Map<TirePosition, String> macs, {
    String? tabTitle,
  }) async {
    final buttons = <CPGridButton>[];
    for (final pos in vehicle.type.positions) {
      buttons.add(await _tireButton(pos, macs[pos]));
    }
    return CPGridTemplate(
      title: '${vehicle.name}  ·  ${vehicle.type.shortLabel}',
      buttons: buttons,
      tabTitle: tabTitle,
    );
  }

  Future<CPGridButton> _tireButton(TirePosition pos, String? mac) async {
    final packet = mac != null ? BleService.instance.latest[mac] : null;
    final isLow = packet != null &&
        packet.pressureBar < LimitsService.instance.minPressureBar;

    final pReadings = TrendService.instance.pressure[pos] ?? [];
    final tReadings = TrendService.instance.temp[pos] ?? [];
    final pArrow = _arrow(pReadings);
    final tArrow = _arrow(tReadings);

    final tilePath = await _tile(pos, packet, isLow);

    String shortTitle;
    String longTitle;

    if (packet == null) {
      shortTitle = '${pos.shortLabel}  No signal';
      longTitle = '${pos.label} · No signal';
    } else {
      shortTitle =
          '${pos.shortLabel}  ${isLow ? "⚠ " : ""}${packet.pressureBar.toStringAsFixed(1)}$pArrow  ${packet.temperatureC}°$tArrow';
      longTitle =
          '${pos.label} · ${isLow ? "⚠ " : ""}${packet.pressureBar.toStringAsFixed(2)} bar $pArrow · ${packet.temperatureC}°C $tArrow';
    }

    return CPGridButton(
      titleVariants: [longTitle, shortTitle],
      image: tilePath,
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

  // ─── Tile renderer ────────────────────────────────────────────────────────
  //
  // 200×200 image: top half = pressure sparkline (cyan),
  //               bottom half = temp sparkline (amber).

  Future<String> _tile(
    TirePosition pos, SensorPacket? packet, bool isLow,
  ) async {
    final key = pos.name;
    if (_tileCache.containsKey(key) && _tileCache[key] != null) {
      return _tileCache[key]!;
    }
    try {
      return await _renderTile(pos, packet, isLow);
    } catch (_) {
      return await _darkSquare(pos);
    }
  }

  // Minimal placeholder — just a dark rounded square
  Future<String> _darkSquare(TirePosition pos) async {
    const size = 200.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size, size));
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, size, size),
        const ui.Radius.circular(14),
      ),
      ui.Paint()..color = const ui.Color(0xFF08111C),
    );
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('${Directory.systemTemp.path}/ftp_ph_${pos.name}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    final path = 'file://${file.path}';
    _tileCache[pos.name] = path;
    return path;
  }

  Future<String> _renderTile(
    TirePosition pos, SensorPacket? packet, bool isLow,
  ) async {
    final key = pos.name;

    const size = 200.0;
    const half = size / 2;
    const pad = 10.0;
    const lineW = 3.5;
    const dotR = 5.0;
    const cornerR = 14.0;

    final pColor = isLow
        ? const ui.Color(0xFFFF5470)  // red alert
        : const ui.Color(0xFF34E3FF); // cyan
    const tColor = ui.Color(0xFFFFB02E); // amber

    final pData = _recent(TrendService.instance.pressure[pos]);
    final tData = _recent(TrendService.instance.temp[pos]);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size, size));

    // ── Background ──────────────────────────────────────────────────────────
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, size, size),
        const ui.Radius.circular(cornerR),
      ),
      ui.Paint()..color = const ui.Color(0xFF08111C),
    );

    // Colour border (thin, matches primary metric status)
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(0, 0, size, size),
        const ui.Radius.circular(cornerR),
      ),
      ui.Paint()
        ..color = pColor.withOpacity(0.35)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // ── Divider ─────────────────────────────────────────────────────────────
    canvas.drawLine(
      ui.Offset(pad, half),
      ui.Offset(size - pad, half),
      ui.Paint()
        ..color = const ui.Color(0xFF1E3040)
        ..strokeWidth = 1.0,
    );

    // ── Pressure sparkline (top half) ───────────────────────────────────────
    _drawSparkline(
      canvas,
      data: pData,
      color: pColor,
      rect: ui.Rect.fromLTWH(pad, pad, size - pad * 2, half - pad * 2),
      lineWidth: lineW,
      dotRadius: dotR,
    );

    // ── Temp sparkline (bottom half) ────────────────────────────────────────
    _drawSparkline(
      canvas,
      data: tData,
      color: tColor,
      rect: ui.Rect.fromLTWH(pad, half + pad, size - pad * 2, half - pad * 2),
      lineWidth: lineW,
      dotRadius: dotR,
    );

    // ── Position label (top-left corner) ────────────────────────────────────
    _drawLabel(canvas, pos.shortLabel, const ui.Offset(pad + 4, pad + 4), pColor);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      _tileCache[key] = null;
      return _fallbackAsset();
    }

    final file = File('${Directory.systemTemp.path}/ftp_tile_${pos.name}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    final path = 'file://${file.path}';
    _tileCache[key] = path;
    return path;
  } // end _renderTile

  List<double>? _recent(List<double>? data) {
    if (data == null || data.length < 2) return null;
    return data.length > 20 ? data.sublist(data.length - 20) : List.from(data);
  }

  void _drawSparkline(
    ui.Canvas canvas, {
    required List<double>? data,
    required ui.Color color,
    required ui.Rect rect,
    required double lineWidth,
    required double dotRadius,
  }) {
    if (data == null || data.length < 2) {
      // No-data placeholder: dashed centre line
      canvas.drawLine(
        ui.Offset(rect.left, rect.center.dy),
        ui.Offset(rect.right, rect.center.dy),
        ui.Paint()
          ..color = color.withOpacity(0.2)
          ..strokeWidth = 1.5,
      );
      return;
    }

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = maxV - minV;

    double px(int i) =>
        rect.left + (i / (data.length - 1)) * rect.width;
    double py(double v) => range < 0.001
        ? rect.center.dy
        : rect.bottom - ((v - minV) / range) * rect.height;

    // Fill
    final fill = ui.Path()..moveTo(px(0), py(data[0]));
    for (int i = 1; i < data.length; i++) fill.lineTo(px(i), py(data[i]));
    fill.lineTo(px(data.length - 1), rect.bottom);
    fill.lineTo(px(0), rect.bottom);
    fill.close();
    canvas.drawPath(
      fill,
      ui.Paint()
        ..color = ui.Color.fromARGB(45, color.red, color.green, color.blue)
        ..style = ui.PaintingStyle.fill,
    );

    // Line
    final line = ui.Path()..moveTo(px(0), py(data[0]));
    for (int i = 1; i < data.length; i++) line.lineTo(px(i), py(data[i]));
    canvas.drawPath(
      line,
      ui.Paint()
        ..color = color
        ..strokeWidth = lineWidth
        ..style = ui.PaintingStyle.stroke
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round,
    );

    // Endpoint dot
    canvas.drawCircle(
      ui.Offset(px(data.length - 1), py(data.last)),
      dotRadius,
      ui.Paint()..color = color,
    );
  }

  void _drawLabel(
    ui.Canvas canvas,
    String text,
    ui.Offset offset,
    ui.Color color,
  ) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 18,
        fontWeight: ui.FontWeight.w700,
      ),
    )
      ..pushStyle(ui.TextStyle(color: color, fontSize: 18, fontWeight: ui.FontWeight.w700))
      ..addText(text);
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 60));
    canvas.drawParagraph(para, offset);
  }

  // ─────────────────────────────────────────────────────────────────────────

  void dispose() {
    _trendSub?.cancel();
    _vehicleSub?.cancel();
    _debounce?.cancel();
    _fcp?.closeConnection();
  }
}
