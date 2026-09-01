enum TirePosition { fl, fr, rl, rr, l, r, ml, mr }

extension TirePositionX on TirePosition {
  String get label {
    switch (this) {
      case TirePosition.fl: return 'Front Left';
      case TirePosition.fr: return 'Front Right';
      case TirePosition.rl: return 'Rear Left';
      case TirePosition.rr: return 'Rear Right';
      case TirePosition.l:  return 'Left';
      case TirePosition.r:  return 'Right';
      case TirePosition.ml: return 'Middle Left';
      case TirePosition.mr: return 'Middle Right';
    }
  }

  String get shortLabel {
    switch (this) {
      case TirePosition.fl: return 'FL';
      case TirePosition.fr: return 'FR';
      case TirePosition.rl: return 'RL';
      case TirePosition.rr: return 'RR';
      case TirePosition.l:  return 'L';
      case TirePosition.r:  return 'R';
      case TirePosition.ml: return 'ML';
      case TirePosition.mr: return 'MR';
    }
  }
}

enum TxTrigger { none, deltaP, lf, scheduled }

class SensorPacket {
  final String mac;
  final double pressureBar;
  final int temperatureC;
  final int statusRaw;
  final TxTrigger txTrigger;
  final bool batteryLow;
  final bool hasFault;
  final int firmwareVersion;
  final int rssi;
  final DateTime timestamp;
  /// Remaining capacity 0-10 (10 = full), -1 if not reported by sensor.
  final int batteryCapacity;
  /// True for packets from the new AES-128-CCM service data format (UUID 0x54504D53).
  /// These always contain the real MAC, so no trigger requirement for pairing.
  final bool newFormat;

  const SensorPacket({
    required this.mac,
    required this.pressureBar,
    required this.temperatureC,
    required this.statusRaw,
    required this.txTrigger,
    required this.batteryLow,
    required this.hasFault,
    required this.firmwareVersion,
    required this.rssi,
    required this.timestamp,
    this.batteryCapacity = -1,
    this.newFormat = false,
  });

  /// Battery percentage string, e.g. "70%" or null if not reported.
  String? get batteryPercent =>
      batteryCapacity >= 0 ? '${(batteryCapacity * 10).clamp(0, 100)}%' : null;

  /// Show in pair screen:
  /// • Legacy sensors: must be LF-triggered or deltaP-triggered so the user can identify which tire.
  /// • New-format sensors: MAC is always in the encrypted payload, so any broadcast is fine.
  bool get isPairingCandidate =>
      newFormat || txTrigger == TxTrigger.lf || txTrigger == TxTrigger.deltaP;
}
