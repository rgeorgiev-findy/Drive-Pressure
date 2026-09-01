# Drive Pressure — FindyTPMS

iOS app for real-time TPMS (Tyre Pressure Monitoring System) via BLE.

## Features

- Live tyre pressure, temperature, and battery status from BLE TPMS sensors
- Background BLE scanning (works when app is terminated)
- CarPlay support
- Push notifications for low/high pressure and low battery
- Sensor pairing flow
- Configurable pressure limits per tyre position

## Sensor Protocol

Sensors advertise with 32-bit service UUID `0x54504D53` ("TPMS").  
The 22-byte service data payload is AES-128-CCM encrypted (RFC 3610):

| Bytes | Content |
|-------|---------|
| 0–4   | Nonce (5 bytes) |
| 5–17  | Ciphertext (13 bytes) |
| 18–21 | Authentication tag (4 bytes) |

CCM parameters: N=7, L=8, t=4.  
Decrypted plaintext: MAC (6B) · gauge pressure LE ×10 mbar (2B) · temp raw−56 (1B) · bat/tyre nibbles (1B) · VIN LE (2B) · flags (1B).

## Requirements

- Flutter 3.x
- iOS 15.0+
- Xcode 15+

## Build

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ipa
```
