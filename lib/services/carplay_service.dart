import 'dart:async';
import 'dart:io';
import 'package:flutter_carplay/flutter_carplay.dart';
import '../models/tire_sensor.dart';
import 'ble_service.dart';
import 'vehicle_service.dart';
import 'limits_service.dart';

class CarPlayService {
  static final CarPlayService instance = CarPlayService._();
  CarPlayService._();

  static const _rootId = 'findytpms_root';

  FlutterCarplay? _fcp;
  StreamSubscription? _bleSub;
  StreamSubscription? _vehicleSub;

  void init() {
    if (!Platform.isIOS) return;

    _fcp = FlutterCarplay();
    _fcp!.addListenerOnConnectionChange((status) {
      if (status == ConnectionStatusTypes.connected) _setRoot();
    });

    _setRoot();

    // On vehicle selection change: rebuild full template structure
    _vehicleSub = VehicleService.instance.changes.listen((_) => _setRoot());

    // On new sensor data: update sections in-place (no flash)
    _bleSub = BleService.instance.packets.listen((_) => _update());
  }

  Future<void> _setRoot() async {
    await FlutterCarplay.setRootTemplate(
      rootTemplate: _buildTemplate(),
      animated: false,
    );
  }

  Future<void> _update() async {
    await _fcp?.updateListTemplateSections(
      elementId: _rootId,
      sections: _buildSections(),
    );
  }

  CPListTemplate _buildTemplate() {
    return CPListTemplate(
      title: 'FindyTPMS',
      sections: _buildSections(),
      emptyViewTitleVariants: ['FindyTPMS'],
      emptyViewSubtitleVariants: ['No vehicles configured'],
      id: _rootId,
    );
  }

  List<CPListSection> _buildSections() {
    final vs = VehicleService.instance;
    final car = vs.activeCar;
    final trailer = vs.activeTrailer;

    if (car == null && trailer == null) {
      return [
        CPListSection(items: [
          CPListItem(
            text: 'No vehicle selected',
            detailText: 'Open FindyTPMS and pick a vehicle',
          ),
        ]),
      ];
    }

    final sections = <CPListSection>[];
    if (car != null) sections.add(_section(car, vs.getPairedMacs(car.id)));
    if (trailer != null) {
      sections.add(_section(trailer, vs.getPairedMacs(trailer.id)));
    }
    return sections;
  }

  CPListSection _section(Vehicle vehicle, Map<TirePosition, String> macs) {
    final items = vehicle.type.positions.map((pos) {
      final mac = macs[pos];
      final packet = mac != null ? BleService.instance.latest[mac] : null;
      final isLow = packet != null &&
          packet.pressureBar < LimitsService.instance.minPressureBar;

      final detail = packet != null
          ? '${isLow ? '⚠ ' : ''}${packet.pressureBar.toStringAsFixed(1)} bar  ${packet.temperatureC}°C'
          : 'No signal';

      return CPListItem(text: pos.label, detailText: detail);
    }).toList();

    return CPListSection(
      header: '${vehicle.name}  ·  ${vehicle.type.shortLabel}',
      items: items,
    );
  }

  void dispose() {
    _bleSub?.cancel();
    _vehicleSub?.cancel();
    _fcp?.closeConnection();
  }
}
