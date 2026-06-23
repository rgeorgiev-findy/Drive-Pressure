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

  // vehicle.id → file:// path for the rendered vehicle image
  final Map<String, String?> _imgCache = {};

  void init() {
    if (!Platform.isIOS) return;
    _fcp = FlutterCarplay();
    _fcp!.addListenerOnConnectionChange((status) {
      if (status == ConnectionStatusTypes.connected) _setRoot();
    });
    _setRoot();
    _vehicleSub = VehicleService.instance.changes.listen((_) {
      _imgCache.clear();
      _setRoot();
    });
    _trendSub = TrendService.instance.updates.listen(_onTrend);
  }

  void _onTrend(TirePosition pos) {
    // Invalidate any vehicle that contains this position
    final vs = VehicleService.instance;
    for (final v in vs.vehicles) {
      if (v.type.positions.contains(pos)) _imgCache.remove(v.id);
    }
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
        sections: [CPListSection(items: [
          CPListItem(
            text: 'No vehicle selected',
            detailText: 'Open FindyTPMS and select a vehicle',
          ),
        ])],
        emptyViewTitleVariants: ['FindyTPMS'],
        emptyViewSubtitleVariants: ['No vehicles configured'],
      );
    } else {
      final buttons = <CPGridButton>[];
      if (car != null) {
        buttons.add(await _vehicleButton(car, vs.getPairedMacs(car.id)));
      }
      if (trailer != null) {
        buttons.add(await _vehicleButton(trailer, vs.getPairedMacs(trailer.id)));
      }
      root = CPGridTemplate(title: 'FindyTPMS', buttons: buttons);
    }

    await FlutterCarplay.setRootTemplate(rootTemplate: root, animated: false);
  }

  // ─── Per-vehicle button ────────────────────────────────────────────────────

  Future<CPGridButton> _vehicleButton(
      Vehicle vehicle, Map<TirePosition, String> macs) async {
    final img = await _vehicleImage(vehicle, macs);
    return CPGridButton(
      titleVariants: ['${vehicle.name} · ${vehicle.type.shortLabel}', vehicle.name],
      image: img,
    );
  }

  // ─── Vehicle image renderer ────────────────────────────────────────────────
  //
  // Generates a single PNG showing the full vehicle layout with all tires
  // in their correct positions, current values, and sparkline charts.

  Future<String> _vehicleImage(
      Vehicle vehicle, Map<TirePosition, String> macs) async {
    if (_imgCache.containsKey(vehicle.id) && _imgCache[vehicle.id] != null) {
      return _imgCache[vehicle.id]!;
    }
    try {
      final path = await _renderVehicle(vehicle, macs);
      _imgCache[vehicle.id] = path;
      return path;
    } catch (e) {
      final path = await _placeholder(vehicle.id);
      _imgCache[vehicle.id] = path;
      return path;
    }
  }

  Future<String> _renderVehicle(
      Vehicle vehicle, Map<TirePosition, String> macs) async {
    const imgW = 400.0;
    const imgH = 400.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, imgW, imgH));

    // ── Background ────────────────────────────────────────────────────────────
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, imgW, imgH), const ui.Radius.circular(16)),
      ui.Paint()..color = const ui.Color(0xFF08111C),
    );

    // ── Vehicle body shape + tire centres ─────────────────────────────────────
    final layout = _layout(vehicle.type, imgW, imgH);
    _drawBody(canvas, layout.body, vehicle.type.isTrailer);

    // ── Tires ─────────────────────────────────────────────────────────────────
    for (final pos in vehicle.type.positions) {
      final center = layout.centers[pos];
      if (center == null) continue;

      final mac = macs[pos];
      final packet = mac != null ? BleService.instance.latest[mac] : null;
      final isLow = packet != null &&
          packet.pressureBar < LimitsService.instance.minPressureBar;

      _drawTire(canvas, center, layout.tireR, pos, packet, isLow);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(imgW.toInt(), imgH.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('toByteData returned null');

    final file =
        File('${Directory.systemTemp.path}/ftp_vehicle_${vehicle.id}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return 'file://${file.path}';
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  _VehicleLayout _layout(VehicleType type, double w, double h) {
    switch (type) {
      case VehicleType.car:
      case VehicleType.trailer4:
        return _VehicleLayout(
          tireR: 32,
          body: ui.Rect.fromLTWH(84, 64, 232, 246),
          centers: {
            TirePosition.fl: ui.Offset(60, 96),
            TirePosition.fr: ui.Offset(340, 96),
            TirePosition.rl: ui.Offset(60, 280),
            TirePosition.rr: ui.Offset(340, 280),
          },
        );
      case VehicleType.trailer2:
        return _VehicleLayout(
          tireR: 36,
          body: ui.Rect.fromLTWH(68, h / 2 - 55, 264, 110),
          centers: {
            TirePosition.l: ui.Offset(w * 0.27, h / 2),
            TirePosition.r: ui.Offset(w * 0.73, h / 2),
          },
        );
      case VehicleType.trailer6:
        return _VehicleLayout(
          tireR: 26,
          body: ui.Rect.fromLTWH(78, 42, 244, 316),
          centers: {
            TirePosition.fl: ui.Offset(58, 72),
            TirePosition.fr: ui.Offset(342, 72),
            TirePosition.ml: ui.Offset(58, 200),
            TirePosition.mr: ui.Offset(342, 200),
            TirePosition.rl: ui.Offset(58, 328),
            TirePosition.rr: ui.Offset(342, 328),
          },
        );
    }
  }

  // ── Body shape ─────────────────────────────────────────────────────────────

  void _drawBody(ui.Canvas canvas, ui.Rect body, bool isTrailer) {
    final rr = ui.RRect.fromRectAndRadius(body, const ui.Radius.circular(20));

    canvas.drawRRect(
      rr,
      ui.Paint()..color = const ui.Color(0xFF0A1420),
    );
    canvas.drawRRect(
      rr,
      ui.Paint()
        ..color = const ui.Color(0xFF1E3040)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (!isTrailer) {
      // Windscreen (front) hint
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(body.left + 30, body.top + 14, body.width - 60, 36),
          const ui.Radius.circular(8),
        ),
        ui.Paint()..color = const ui.Color(0xFF0D1B2A),
      );
    }
  }

  // ── Single tire slot ───────────────────────────────────────────────────────

  void _drawTire(
    ui.Canvas canvas,
    ui.Offset center,
    double r,
    TirePosition pos,
    SensorPacket? packet,
    bool isLow,
  ) {
    final color = isLow
        ? const ui.Color(0xFFFF5470)  // red alert
        : const ui.Color(0xFF34E3FF); // cyan

    // Outer glow
    canvas.drawCircle(
      center,
      r + 3,
      ui.Paint()
        ..color = ui.Color.fromARGB(40, color.red, color.green, color.blue)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );

    // Tire background
    canvas.drawCircle(center, r, ui.Paint()..color = const ui.Color(0xFF0A1825));

    // Tire border
    canvas.drawCircle(
      center, r,
      ui.Paint()
        ..color = color
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── Text inside circle ──────────────────────────────────────────────────
    if (packet != null) {
      final pressText =
          isLow ? '⚠${packet.pressureBar.toStringAsFixed(1)}' : packet.pressureBar.toStringAsFixed(2);
      _text(canvas, pressText, ui.Offset(center.dx, center.dy - 8),
          size: r * 0.44, color: color, bold: true);
      _text(canvas, '${packet.temperatureC}°C',
          ui.Offset(center.dx, center.dy + 10),
          size: r * 0.30, color: const ui.Color(0xFFFFB02E));
    } else {
      _text(canvas, '—', center, size: r * 0.40,
          color: const ui.Color(0xFF52606F));
    }

    // ── Position label ──────────────────────────────────────────────────────
    _text(canvas, pos.shortLabel,
        ui.Offset(center.dx, center.dy - r - 14),
        size: 11, color: const ui.Color(0xFF8AA0B2));

    // ── Sparklines below circle ──────────────────────────────────────────────
    final sparkW = r * 2.4;
    final sparkH = 12.0;
    final sparkX = center.dx - sparkW / 2;
    final pY = center.dy + r + 5;
    final tY = pY + sparkH + 4;

    _sparkline(canvas,
        data: _recent(TrendService.instance.pressure[pos]),
        color: color,
        rect: ui.Rect.fromLTWH(sparkX, pY, sparkW, sparkH));

    _sparkline(canvas,
        data: _recent(TrendService.instance.temp[pos]),
        color: const ui.Color(0xFFFFB02E),
        rect: ui.Rect.fromLTWH(sparkX, tY, sparkW, sparkH));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _sparkline(
    ui.Canvas canvas, {
    required List<double>? data,
    required ui.Color color,
    required ui.Rect rect,
  }) {
    if (data == null || data.length < 2) {
      canvas.drawLine(
        ui.Offset(rect.left, rect.center.dy),
        ui.Offset(rect.right, rect.center.dy),
        ui.Paint()
          ..color = color.withOpacity(0.2)
          ..strokeWidth = 1,
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
    canvas.drawPath(fill,
        ui.Paint()
          ..color = ui.Color.fromARGB(40, color.red, color.green, color.blue)
          ..style = ui.PaintingStyle.fill);

    // Line
    final line = ui.Path()..moveTo(px(0), py(data[0]));
    for (int i = 1; i < data.length; i++) line.lineTo(px(i), py(data[i]));
    canvas.drawPath(line,
        ui.Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = ui.PaintingStyle.stroke
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round);

    // Dot
    canvas.drawCircle(
      ui.Offset(px(data.length - 1), py(data.last)),
      2.5,
      ui.Paint()..color = color,
    );
  }

  void _text(
    ui.Canvas canvas,
    String text,
    ui.Offset center, {
    required double size,
    required ui.Color color,
    bool bold = false,
  }) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontSize: size,
      fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w500,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? ui.FontWeight.w700 : ui.FontWeight.w500,
      ))
      ..addText(text);
    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: size * text.length * 0.7 + 10));
    canvas.drawParagraph(
      para,
      ui.Offset(center.dx - para.maxIntrinsicWidth / 2, center.dy - size / 2),
    );
  }

  List<double>? _recent(List<double>? data) {
    if (data == null || data.length < 2) return null;
    return data.length > 20 ? data.sublist(data.length - 20) : List.from(data);
  }

  Future<String> _placeholder(String id) async {
    const size = 400.0;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, size, size));
    c.drawRRect(
      ui.RRect.fromRectAndRadius(
          ui.Rect.fromLTWH(0, 0, size, size), const ui.Radius.circular(16)),
      ui.Paint()..color = const ui.Color(0xFF08111C),
    );
    final pic = rec.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('${Directory.systemTemp.path}/ftp_ph_$id.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return 'file://${file.path}';
  }

  void dispose() {
    _trendSub?.cancel();
    _vehicleSub?.cancel();
    _debounce?.cancel();
    _fcp?.closeConnection();
  }
}

// ── Data classes ────────────────────────────────────────────────────────────

class _VehicleLayout {
  final double tireR;
  final ui.Rect body;
  final Map<TirePosition, ui.Offset> centers;
  const _VehicleLayout(
      {required this.tireR, required this.body, required this.centers});
}
