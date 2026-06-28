# Implementation Status

## Selected Tech Stack

- Main backend: C# ASP.NET Core 8 Minimal API.
- Database: SQLite, using the schema in `backend/schema.sql`.
- Mobile operator app: PWA in `mobile_app/`, calling the C# backend API at `http://127.0.0.1:8000`.
- Flutter operator app source: `flutter_app/`, calling the same C# backend API.
- IoT realtime bridge: MQTT via `MQTTnet` and public broker topic prefix `traffic/hainx-iot-traffic-light`.
- Device simulation: ESP32/Wokwi using Arduino C/C++ in `wokwi/sketch.ino`.

Arduino/ESP32 does not require C#. The `.ino` file is expected to use Arduino C/C++. C# is used as the main application/backend stack for the MVP.

## Level 1 Coverage

- Wokwi supports AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, and EMERGENCY modes.
- Wokwi diagram now shows 4 visual signal clusters: NORTH, SOUTH, EAST, and WEST.
- LCD, buttons, and Serial commands are implemented in the Wokwi sketch.
- Backend exposes status, command, history, and logs APIs.
- SQLite stores command history, traffic logs, phase plans, approaches, signal heads, and conflict rules.
- PWA displays the current mode, phase, countdown, signal state, and command history from the backend.
- PWA now includes operator dashboard panels: metrics, four approach signals, signal heads, phase plan, mode priority, roads, history, and logs.

## Level 2 Coverage

- PWA calls the real C# backend API.
- Flutter app has Dashboard, Control, Manage, History, and Settings screens for the C# API.
- Manage supports real phase-plan update/activation and road enable/disable calls.
- Backend persists data in real SQLite tables.
- PWA includes road/approach management for a multi-road intersection model.
- Database schema supports N road approaches, N signal heads, and phase plans.
- Backend code is organized around database/repository/service responsibilities.
- Backend exposes `/api/intersections/1/dashboard` for a complete dashboard snapshot.
- Backend publishes commands to MQTT and subscribes to Wokwi status/ack topics.
- Wokwi sketch connects to `Wokwi-GUEST`, subscribes to MQTT commands, and publishes status/ack.
- Repo includes deploy-ready files: `backend/Dockerfile`, `backend/.dockerignore`, and `render.yaml`.

## End-to-End MQTT Path

```text
Flutter/PWA -> C# API -> broker.hivemq.com -> ESP32/Wokwi
ESP32/Wokwi -> broker.hivemq.com -> C# API -> Flutter/PWA
```

Default topics:

```text
traffic/hainx-iot-traffic-light/intersections/1/commands
traffic/hainx-iot-traffic-light/intersections/1/status
traffic/hainx-iot-traffic-light/intersections/1/acks
```

## How To Run

Use .NET SDK 8:

```powershell
cd backend
dotnet restore
dotnet run
```

Then run the PWA:

```powershell
python -m http.server 4173
```

Open:

```text
http://localhost:4173/mobile_app/
```

Run Flutter Web with the portable SDK:

```powershell
subst T: "$PWD"
cd T:\flutter_app
T:\.flutter\bin\flutter.bat pub get
T:\.flutter\bin\flutter.bat run -d chrome
```

Build the Android APK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build-flutter-android.ps1
```

## Verification Notes

- `mobile_app/app.js` passes `node --check`.
- `dotnet build backend/TrafficLightMvp.csproj` passes with 0 warnings and 0 errors. Re-verified on 2026-06-18 via `scripts/verify-backend.ps1` (0 Warning(s), 0 Error(s)).
- `dotnet build backend/TrafficLightMvp.csproj -c Release -p:UseAppHost=false` passes with 0 warnings and 0 errors.
- Backend integration tests pass: 8/8 tests in `backend/tests/TrafficLightMvp.IntegrationTests`. Re-verified on 2026-06-18 via `scripts/verify-backend.ps1` (Passed: 8, Failed: 0, Skipped: 0).
- `scripts/verify-backend.ps1` automates build + test for the C# backend using the portable .NET 8 SDK shipped under `.dotnet/`.
- Backend smoke test passes against `http://127.0.0.1:8000`.
- MQTT bridge connected successfully to `broker.hivemq.com:1883` during local verification.
- Portable Flutter 3.44.2 and Android SDK 36 are installed in ignored workspace folders.
- `flutter analyze` passes with no issues. Re-verified on 2026-06-18 via `scripts/verify-flutter.ps1` ("No issues found! (ran in 11.1s)").
- Flutter widget tests pass. Re-verified on 2026-06-18 via `scripts/verify-flutter.ps1` ("All tests passed!" for `renders traffic operator app`).
- `scripts/verify-flutter.ps1` automates the T: subst, stale build cleanup, `flutter analyze`, and `flutter test` against the Flutter operator app.
- Flutter Web release build passes.
- Android release build passed in the latest verified run and wrote `dist/android/iot-traffic-light-v1.0.0.apk` as the build output.
- Flutter Manage screen was browser-verified on desktop and mobile. Phase-plan save and road enable/disable call the real backend API.
- Wokwi `diagram.json` parses as valid JSON with 30 parts and 48 connections.
- `wokwi/sketch.ino` passes a local brace-balance scan that ignores strings/comments.
- `scripts/test-wokwi-source.ps1` now wraps the local Wokwi sanity checks.
- `scripts/run-backend-demo.ps1` now starts the C# API with LAN access and MQTT settings for phone demos.
- Wokwi UI compile/run has been verified in a temporary ESP32 project.
- Backend received live device status from `wokwi-esp32-01` via MQTT.
- E2E API -> MQTT -> Wokwi -> ACK was verified for command IDs 22-26: AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, and EMERGENCY.
- Wokwi evidence screenshots are saved in `assets/wokwi/`.
- The APK has not yet been installed and verified on a physical Android phone.
