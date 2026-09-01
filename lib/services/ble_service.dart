import 'dart:async';
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tire_sensor.dart';
import 'sensor_store.dart';
import 'vehicle_service.dart';

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

  // AES-128-CCM key for firmware v2 service data (32-bit UUID 0x54504D53)
  static const String _tpmsV2KeyHex = 'D6C81D70443AAA96B0AB5914752CEB92';

  static const _nativeBleChannel = MethodChannel('eu.findy.drivePressure/native_ble');

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

    if (Platform.isIOS) {
      _nativeBleChannel.setMethodCallHandler(_onNativePacket);
    }
  }

  /// Receives BLE packets pushed by native FindyBLEManager while in background.
  /// Feeds them into the same pipeline as foreground scan results so that
  /// AlertsService, TrendService, and CarPlayService all stay up to date.
  Future<dynamic> _onNativePacket(MethodCall call) async {
    if (call.method != 'packet') return;
    final d = Map<String, dynamic>.from(call.arguments as Map);
    final mac = d['mac'] as String? ?? '';
    if (mac.isEmpty) return;
    final pressure = (d['pressure'] as num?)?.toDouble() ?? -1.0;
    final packet = SensorPacket(
      mac: mac,
      pressureBar: pressure >= 0 ? pressure : 0.0,
      temperatureC: (d['temp'] as num?)?.toInt() ?? 20,
      statusRaw: 0,
      txTrigger: TxTrigger.scheduled,
      batteryLow: d['battLow'] as bool? ?? false,
      hasFault: d['fault'] as bool? ?? false,
      firmwareVersion: 0,
      rssi: -80,
      timestamp: DateTime.now(),
      batteryCapacity: (d['battCapacity'] as num?)?.toInt() ?? -1,
      newFormat: true,
    );
    _latest[mac] = packet;
    _packetController.add(packet);
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

    // Never call startScan when BT is not supported or not on
    if (!await FlutterBluePlus.isSupported) return;

    final granted = await requestPermissions();
    if (!granted) return;

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 15),
      );
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.onScanResults.listen(_onResults);
    } catch (_) {}
  }

  Future<void> stopScan() async {
    _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
  }

  void _onResults(List<ScanResult> results) {
    for (final r in results) {
      // New firmware: 32-bit Service Data UUID 0x54504D53 ("TPMS")
      final svcPacket = _parseNewServiceData(r);
      if (svcPacket != null) {
        _latest[svcPacket.mac] = svcPacket;
        _packetController.add(svcPacket);
        continue;
      }

      // Legacy firmware: Sensata manufacturer data
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

  /// Parses the new Service Data packet (AD type 0x20, UUID 0x54504D53).
  /// Service data is AES-128-CCM encrypted: [nonce 5B][ciphertext 13B][tag 4B] = 22 B.
  /// Returns null if advertisement doesn't contain this service data or tag fails.
  SensorPacket? _parseNewServiceData(ScanResult r) {
    final svcData = r.advertisementData.serviceData;
    List<int>? payload;
    for (final e in svcData.entries) {
      if (e.key.str.toUpperCase().startsWith('54504D53')) {
        payload = e.value;
        break;
      }
    }
    if (payload == null || payload.length < 22) return null;

    final nonce5     = payload.sublist(0, 5);
    final ciphertext = payload.sublist(5, 18);
    final tag        = payload.sublist(18, 22);

    // CCM IV (7 B): "TP" + nonce5
    final nonce7 = [0x54, 0x50, ...nonce5];
    // Associated Data (9 B): UUID LE wire order + nonce5
    final ad = [0x53, 0x4D, 0x50, 0x54, ...nonce5];

    final key = _hexToBytes(_tpmsV2KeyHex);
    final plain = _ccmDecrypt(key: key, nonce7: nonce7, ad: ad,
                              ciphertext: ciphertext, tag: tag);
    if (plain == null) return null;

    // Plaintext [0-5] MAC MSB first
    final mac = plain
        .sublist(0, 6)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');

    final pressureRaw = plain[6] | (plain[7] << 8);
    if (pressureRaw == 0xFFFF) return null;
    final pressureBar = pressureRaw * 10.0 / 1000.0;

    final tempC = plain[8] - 56;
    final batteryCapacity = (plain[9] >> 4) & 0x0F;

    final flags      = plain[12];
    final battLow    = (flags & 0x08) != 0;  // bit 3
    final hasFault   = (flags & 0x04) != 0;  // bit 2 = sensor error
    final wakeReason = flags & 0x03;

    const wakeToTrigger = [
      TxTrigger.scheduled,
      TxTrigger.none,
      TxTrigger.deltaP,
      TxTrigger.lf,
    ];
    final txTrigger = wakeToTrigger[wakeReason.clamp(0, 3)];

    return SensorPacket(
      mac: mac,
      pressureBar: pressureBar,
      temperatureC: tempC,
      statusRaw: 0,
      txTrigger: txTrigger,
      batteryLow: battLow,
      hasFault: hasFault,
      firmwareVersion: 0,
      rssi: r.rssi,
      timestamp: DateTime.now(),
      batteryCapacity: batteryCapacity,
      newFormat: true,
    );
  }

  /// AES-128-CCM decryption (RFC 3610).
  /// nonce7 is 7 bytes → N=7, L=15-7=8, t=4.
  /// Returns plaintext if tag verifies, null otherwise.
  Uint8List? _ccmDecrypt({
    required List<int> key,
    required List<int> nonce7,
    required List<int> ad,
    required List<int> ciphertext,
    required List<int> tag,
  }) {
    if (key.length != 16 || nonce7.length != 7 || tag.length != 4) return null;

    final keyObj = enc.Key(Uint8List.fromList(key));
    final encr = enc.Encrypter(enc.AES(keyObj, mode: enc.AESMode.ecb, padding: null));

    List<int> encBlock(List<int> input) =>
        encr.encryptBytes(Uint8List.fromList(input)).bytes;

    final msgLen = ciphertext.length;
    // N=7 → L=8: counter field is 8 bytes, flags byte = L-1 = 7 = 0x07
    const Lm1 = 7; // L-1

    // CTR decrypt: counter starts at 1
    // Counter block: [0x07][nonce7 7B][counter in 8 bytes BE]
    final plain = List<int>.filled(msgLen, 0);
    final numBlocks = (msgLen + 15) ~/ 16;
    for (int bn = 1; bn <= numBlocks; bn++) {
      final ctr = List<int>.filled(16, 0);
      ctr[0] = Lm1;
      for (int j = 0; j < 7; j++) ctr[1 + j] = nonce7[j];
      // 8-byte counter at ctr[8..15]; bn fits in last 2 bytes for realistic sizes
      ctr[14] = (bn >> 8) & 0xFF;
      ctr[15] = bn & 0xFF;
      final stream = encBlock(ctr);
      final offset = (bn - 1) * 16;
      final blockLen = min(16, msgLen - offset);
      for (int j = 0; j < blockLen; j++) {
        plain[offset + j] = ciphertext[offset + j] ^ stream[j];
      }
    }

    // CBC-MAC — B0: flags | nonce7 (7B) | msgLen in L=8 bytes BE
    // flags = (Adata=1<<6) | (M'=(t-2)/2=1 <<3) | (L'=L-1=7)
    //       = 0b01001111 = 0x4F
    final b0 = List<int>.filled(16, 0);
    b0[0] = 0x4F;
    for (int j = 0; j < 7; j++) b0[1 + j] = nonce7[j];
    // msgLen in 8 bytes BE at b0[8..15]; msgLen=13 fits in last byte
    b0[15] = msgLen & 0xFF;
    var cbc = encBlock(b0);

    // AD: 2-byte length prefix + AD bytes, padded to 16
    final adEnc = <int>[(ad.length >> 8) & 0xFF, ad.length & 0xFF, ...ad];
    final adPad = (16 - (adEnc.length % 16)) % 16;
    adEnc.addAll(List.filled(adPad, 0));
    for (int i = 0; i < adEnc.length; i += 16) {
      final block = List.generate(16, (j) => cbc[j] ^ adEnc[i + j]);
      cbc = encBlock(block);
    }

    // Plaintext blocks, padded to 16
    final ptPad = [...plain, ...List.filled((16 - (msgLen % 16)) % 16, 0)];
    for (int i = 0; i < ptPad.length; i += 16) {
      final block = List.generate(16, (j) => cbc[j] ^ ptPad[i + j]);
      cbc = encBlock(block);
    }
    final cbcTag = cbc.sublist(0, 4);

    // A0: [0x07][nonce7][0x00…0x00] — encrypt to mask tag
    final a0 = List<int>.filled(16, 0);
    a0[0] = Lm1;
    for (int j = 0; j < 7; j++) a0[1 + j] = nonce7[j];
    final a0enc = encBlock(a0);

    // Verify tag
    int diff = 0;
    for (int i = 0; i < 4; i++) diff |= (cbcTag[i] ^ a0enc[i]) ^ tag[i];
    if (diff != 0) return null;

    return Uint8List.fromList(plain);
  }

  static List<int> _hexToBytes(String hex) => List.generate(
      hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));

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

    final battByte    = payload[6];
    final battPresent = (battByte & 0x01) == 1;
    final batteryLow  = ((battByte >> 1) & 0x01) == 1;
    // Bits 4-7: remaining capacity 0-10 (10 = full). -1 if sensor doesn't report it.
    final batteryCapacity = battPresent ? (battByte >> 4) & 0x0F : -1;

    // On iOS, r.device.remoteId is a random UUID — extract real MAC from payload bytes [7-12]
    // On Android, remoteId is already the real BLE MAC address
    final String mac;
    if (Platform.isIOS) {
      mac = payload.sublist(7, 13).reversed
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
      batteryCapacity: batteryCapacity,
    );
  }

  /// Restores the latest sensor readings cached by native FindyBLEManager
  /// while the app was in background or terminated. Call this once at startup,
  /// after SensorStore and VehicleService are initialized.
  /// Data older than 30 minutes is ignored.
  Future<void> restoreFromCache() async {
    if (!Platform.isIOS) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    const maxAgeSeconds = 30 * 60.0;

    for (final pos in TirePosition.values) {
      final base = 'sensor_cache_${pos.name}_';
      final ts = prefs.getDouble(base + 'ts');
      if (ts == null || (now - ts) > maxAgeSeconds) continue;

      final pressure = prefs.getDouble(base + 'pressure');
      if (pressure == null) continue;

      // Find the MAC paired to this position
      String? mac = SensorStore.instance.pairedMacs[pos];
      if (mac == null) {
        for (final v in VehicleService.instance.vehicles) {
          mac = VehicleService.instance.getMac(v.id, pos);
          if (mac != null) break;
        }
      }
      if (mac == null) continue;

      final packet = SensorPacket(
        mac: mac,
        pressureBar: pressure >= 0 ? pressure : 0.0,
        temperatureC: prefs.getInt(base + 'temp') ?? 20,
        statusRaw: 0,
        txTrigger: TxTrigger.scheduled,
        batteryLow: prefs.getBool(base + 'batt_low') ?? false,
        hasFault: prefs.getBool(base + 'fault') ?? false,
        firmwareVersion: 0,
        rssi: -80,
        timestamp: DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt()),
        batteryCapacity: prefs.getInt(base + 'batt_capacity') ?? -1,
      );
      _latest[mac] = packet;
      _packetController.add(packet);
    }
  }

  void dispose() {
    _scanSub?.cancel();
    _packetController.close();
  }
}
