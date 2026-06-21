import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:permission_handler/permission_handler.dart';
import '../models/tire_sensor.dart';

class _VendorSpec {
  final int mfrId;
  final enc.Encrypter encrypter;
  // Byte offset past the Sensata MUX+Version header (both vendors use 2).
  final int dataOffset;

  const _VendorSpec({
    required this.mfrId,
    required this.encrypter,
    this.dataOffset = 2,
  });
}

class BleService {
  static final BleService instance = BleService._();
  BleService._();

  static const int _schraderMfrId = 0x0601;
  static const int _sensataMux    = 0x06;
  static const String _schraderKeyHex = '4679846FC84A9DD013F601E16D40E350';

  static const int _vendor2MfrId = 0x4C00;
  static const String _vendor2KeyHex = '3ddf863dcc71c5273989cd77583cf70c';

  late List<_VendorSpec> _vendors;

  final _packetController = StreamController<SensorPacket>.broadcast();
  Stream<SensorPacket> get packets => _packetController.stream;

  final Map<String, SensorPacket> _latest = {};
  Map<String, SensorPacket> get latest => Map.unmodifiable(_latest);

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _vendors = [
      _VendorSpec(
        mfrId: _schraderMfrId,
        encrypter: _makeEncrypter(_schraderKeyHex),
      ),
      _VendorSpec(
        mfrId: _vendor2MfrId,
        encrypter: _makeEncrypter(_vendor2KeyHex),
      ),
    ];
  }

  static enc.Encrypter _makeEncrypter(String hexKey) {
    final key = enc.Key.fromBase16(hexKey);
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.ecb, padding: null));
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      // iOS handles Bluetooth via Info.plist — no runtime permission needed
      return true;
    }
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> startScan() async {
    await init();
    final granted = await requestPermissions();
    if (!granted) return;

    if (await FlutterBluePlus.isScanning.first) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.startScan(
      continuousUpdates: true,
      removeIfGone: const Duration(seconds: 15),
    );

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.onScanResults.listen(_onResults);
  }

  Future<void> stopScan() async {
    _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
  }

  void _onResults(List<ScanResult> results) {
    for (final r in results) {
      final mfrData = r.advertisementData.manufacturerData;

      for (final vendor in _vendors) {
        final rawData = mfrData[vendor.mfrId];
        if (rawData == null) continue;

        final packet = _parseSensata(rawData, vendor, r);
        if (packet != null) {
          _latest[packet.mac] = packet;
          _packetController.add(packet);
        }
        break;
      }
    }
  }

  /// Both vendors use Sensata format: [MUX=0x06][Version][16-byte ciphertext]
  /// Version 0x01 = plaintext, 0x02 = AES-128 ECB.
  SensorPacket? _parseSensata(
      List<int> rawData, _VendorSpec vendor, ScanResult r) {
    if (rawData.length < 18) return null;
    if (rawData[0] != _sensataMux) return null;

    final version = rawData[1];
    List<int> payload;

    if (version == 0x01) {
      payload = rawData.sublist(2, 18);
    } else if (version == 0x02) {
      final cipher = Uint8List.fromList(rawData.sublist(2, 18));
      try {
        payload = vendor.encrypter.decryptBytes(enc.Encrypted(cipher));
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }

    return _decodePayload(payload, r);
  }

  /// Payload layout (16 bytes, post-decryption):
  ///   [0-1]  Pressure  16-bit LE, raw×10 / 1000 = bar gauge
  ///   [2]    Temp      raw − 56 = °C
  ///   [3-4]  Status    16-bit LE (bits 3-4 = TX trigger, bit 5 = fault)
  ///   [5]    Firmware version
  ///   [6]    Battery   bit 1 = low
  ///   [7-15] Device address + block counter
  SensorPacket? _decodePayload(List<int> payload, ScanResult r) {
    if (payload.length < 16) return null;

    final pressureRaw = payload[0] | (payload[1] << 8);
    if (pressureRaw == 0x0000 || pressureRaw == 0xFFFF) return null;
    final pressureBar = pressureRaw * 10.0 / 1000.0;

    final tempC = payload[2] - 56;

    final status  = payload[3] | (payload[4] << 8);
    final txBits  = (status >> 3) & 0x03;
    final txTrigger = TxTrigger.values[txBits.clamp(0, 3)];
    final hasFault  = ((status >> 5) & 0x01) == 1;

    final batteryLow = ((payload[6] >> 1) & 0x01) == 1;

    // On iOS, r.device.remoteId is a random UUID — extract real MAC from payload bytes [7-12]
    // On Android, remoteId is already the real BLE MAC address
    final String mac;
    if (Platform.isIOS) {
      mac = payload.sublist(7, 13)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
    } else {
      mac = r.device.remoteId.str;
    }

    return SensorPacket(
      mac: mac,
      pressureBar: pressureBar,
      temperatureC: tempC,
      statusRaw: status,
      txTrigger: txTrigger,
      batteryLow: batteryLow,
      hasFault: hasFault,
      firmwareVersion: payload[5],
      rssi: r.rssi,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    _scanSub?.cancel();
    _packetController.close();
  }
}
