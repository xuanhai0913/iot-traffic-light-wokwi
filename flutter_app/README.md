# Flutter Mobile App

This is the mobile operator app for the IoT Traffic Light project.

The app calls the C# backend API and controls the demo intersection:

```text
Flutter -> C# API -> SQLite
Flutter -> C# API -> MQTT Broker -> ESP32/Wokwi
```

## Run Web

```powershell
subst T: "$PWD"
cd T:\flutter_app
T:\.flutter\bin\flutter.bat pub get
T:\.flutter\bin\flutter.bat run -d chrome
```

The `T:` alias avoids Windows/Gradle issues caused by the Unicode OneDrive
workspace path.

## Build Android APK

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\build-flutter-android.ps1
```

The script stages the Flutter project outside OneDrive, runs analyze/tests,
builds a release APK, and copies it to:

```text
dist/android/iot-traffic-light-v1.0.0.apk
```

## API URL

Default API URL:

```text
http://10.0.2.2:8000
```

Use this for Android Emulator because `10.0.2.2` points to the host computer.

For a real phone on the same WiFi, replace it in the Settings screen:

```text
http://YOUR_PC_IP:8000
```

Example:

```text
http://192.168.1.10:8000
```

The easiest way to get the correct PC IP and start the backend for phone testing is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File T:\scripts\run-backend-demo.ps1
```

## Screens

- Dashboard: current mode, phase, countdown, signal state.
- Control: send AUTO, NIGHT, PRIORITY NS, PRIORITY EW, EMERGENCY commands.
- Manage: update/activate phase plans and enable/disable road approaches.
- History: recent backend command history.
- Settings: update API base URL, test connection, and view ESP32 last seen.
