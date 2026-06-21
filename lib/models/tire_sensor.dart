enum TirePosition { fl, fr, rl, rr }

extension TirePositionX on TirePosition {
  String get label {
    switch (this) {
      case TirePosition.fl: return 'Front Left';
      case TirePosition.fr: return 'Front Right';
      case TirePosition.rl: return 'Rear Left';
      case TirePosition.rr: return 'Rear Right';
    }
  }

  String get shortLabel {
    switch (this) {
      case TirePosition.fl: return 'FL';
      case TirePosition.fr: return 'FR';
      case TirePosition.rl: return 'RL';
      case TirePosition.rr: return 'RR';
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
  });

  /// Sensor is LF-triggered or DeltaP-triggered → show in pair screen.
  bool get isPairingCandidate =>
      txTrigger == TxTrigger.lf || txTrigger == TxTrigger.deltaP;
}
