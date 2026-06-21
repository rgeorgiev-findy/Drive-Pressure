# DrivePressure — Flutter UI

A Flutter port of the DrivePressure TPMS concept (liquid-glass background + cockpit telemetry).

## Run

```bash
flutter pub get
flutter run
```

Requires Flutter 3.x (Dart 3). Fonts are pulled at runtime via `google_fonts`
(Chakra Petch · Share Tech Mono · Sora · Space Mono) — no asset files needed.

## Screens (`lib/screens/`)

| File | What |
|------|------|
| `splash_screen.dart` | Branded splash + tire logo |
| `vehicle_screen.dart` | Logo + alerts; top-down car, 4 wheels (red = problem, “+” = pair) |
| `tire_detail_screen.dart` | Full sensor data + 24h trend + delete |
| `pair_ble_screen.dart` | BLE scan, detected transmitters (pressure/temp/MAC) |
| `alerts_screen.dart` | Active / resolved alert feed |
| `limits_screen.dart` | Pressure & temperature thresholds + alarm toggles |

Bottom tabs are **Home · Alerts · Limits**. Navigation lives in
`lib/main_shell.dart` (tabs + pushed detail/pair routes).

## Shared widgets (`lib/widgets/`)

`gauge_ring.dart` (270° telemetry gauge), `tire_logo.dart`, `tire_slot.dart`,
`glass.dart` (frosted card), `app_background.dart` (cool gradient mesh),
`bottom_nav.dart`, `buttons.dart`, `mini_trend.dart`, `status_row.dart`.

Theme/colors/text in `lib/theme/app_theme.dart`.

> Note: the phone bezel in the design board was a presentation device only — these
> screens are full-bleed `Scaffold`s, ready to ship. The faux `StatusRow` (9:41 / 100%)
> mirrors the comps; delete it if you prefer the real system status bar.
