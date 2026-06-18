# Wokwi Simulation Setup

This folder contains the ESP32 traffic light simulation used for screenshots and the demo video.

## Files

- `sketch.ino`: ESP32/Arduino C++ controller code.
- `diagram.json`: Wokwi circuit with ESP32, LCD, 4 visual signal clusters, buttons, and resistors.
- `libraries.txt`: Wokwi library list.

## Open In Wokwi

Before opening the simulator, run the local sanity check from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\test-wokwi-source.ps1
```

This does not replace Wokwi compilation, but it catches common local mistakes such as invalid `diagram.json`, missing libraries, and unbalanced braces in `sketch.ino`.

1. Open Wokwi and create a new ESP32 project.
2. Replace the default `sketch.ino` with this repo file: `wokwi/sketch.ino`.
3. Replace the default `diagram.json` with this repo file: `wokwi/diagram.json`.
4. Add or replace `libraries.txt` with this repo file: `wokwi/libraries.txt`.
5. Press Start Simulation.
6. Zoom/fit the circuit so the LCD, NORTH/SOUTH/EAST/WEST LEDs, and buttons are all visible.

## Demo Controls

Use either Wokwi buttons or Serial Monitor commands.

| Mode | Button | Serial command | Expected visual |
|---|---|---|---|
| AUTO | AUTO | `a` or `auto` | NS green/yellow then EW green/yellow cycle |
| NIGHT | NIGHT | `n` or `night` | Yellow warning blink |
| PRIORITY NS | PRIORITY once | `p` or `priority_ns` | North/South green, East/West red |
| PRIORITY EW | Serial recommended | `pe` or `priority_ew` | East/West green, North/South red |
| EMERGENCY | EMERGENCY | `e` or `emergency` | All directions red |

## MQTT Control

The sketch also supports remote control through MQTT:

```text
WiFi: Wokwi-GUEST
Broker: broker.hivemq.com:1883
Command topic: traffic/hainx-iot-traffic-light/intersections/1/commands
Status topic: traffic/hainx-iot-traffic-light/intersections/1/status
Ack topic: traffic/hainx-iot-traffic-light/intersections/1/acks
```

This path works with Wokwi Public Gateway because both the C# backend and ESP32/Wokwi connect outbound to the same public MQTT broker.

Expected command payload from backend:

```json
{
  "commandId": 17,
  "intersectionId": 1,
  "command": "SET_EMERGENCY",
  "modeCode": "EMERGENCY",
  "source": "flutter",
  "createdBy": "operator"
}
```

The `command` field accepts exactly these five backend commands:

| Command | Resulting mode |
|---|---|
| `SET_AUTO` | `AUTO` |
| `SET_NIGHT` | `NIGHT` |
| `SET_PRIORITY_NS` | `PRIORITY_NS` |
| `SET_PRIORITY_EW` | `PRIORITY_EW` |
| `SET_EMERGENCY` | `EMERGENCY` |

Commands are case-insensitive in the firmware. The short aliases in the Demo Controls table are intended for local Serial use.

For a supported command, the ESP32 publishes an ACK such as:

```json
{
  "intersectionId": 1,
  "deviceId": "wokwi-esp32-01",
  "commandId": 17,
  "command": "SET_EMERGENCY",
  "status": "acknowledged",
  "message": "Mode changed"
}
```

An unsupported or malformed command is published with `"status":"rejected"` and `"command":"UNKNOWN"`. Device status is published after connection, after a mode change has been applied to the lights, and every 2 seconds:

```json
{
  "intersectionId": 1,
  "deviceId": "wokwi-esp32-01",
  "modeCode": "EMERGENCY",
  "phaseCode": "ALL_RED",
  "remainingSeconds": -1,
  "signals": [
    { "approach": "NORTH", "signal": "NORTH_MAIN", "color": "RED" }
  ]
}
```

The real status contains all four `NORTH`, `SOUTH`, `EAST`, and `WEST` signal entries. Each simulated ESP32 derives a unique MQTT client ID from its chip ID so two Wokwi sessions do not disconnect each other.

The ESP32 still supports local button/Serial control if WiFi or MQTT is offline.

The sketch also accepts a payload that only contains `modeCode`, for example:

```json
{ "commandId": 18, "modeCode": "NIGHT" }
```
WiFi and MQTT reconnect attempts are spaced 10 seconds apart. The synchronous TCP/MQTT attempt uses short timeouts, and button/Serial/state-machine work runs before each network update.

## Capture Output Names

Save screenshots and video using these names:

| Artifact | Save path |
|---|---|
| AUTO screenshot | `assets/wokwi/wokwi_auto.png` |
| NIGHT screenshot | `assets/wokwi/wokwi_night.png` |
| PRIORITY NS screenshot | `assets/wokwi/wokwi_priority_ns.png` |
| PRIORITY EW screenshot | `assets/wokwi/wokwi_priority_ew.png` |
| EMERGENCY screenshot | `assets/wokwi/wokwi_emergency.png` |
| Demo video | `demo/demo_wokwi.mp4` |

## Verified Evidence

The current repo source was loaded into a temporary Wokwi ESP32 project on 2026-06-15. Compile/run completed, backend received `wokwi-esp32-01` over MQTT, and API commands were acknowledged for AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, and EMERGENCY.

Saved screenshots:

- `assets/wokwi/wokwi_compile_run.png`
- `assets/wokwi/wokwi_auto.png`
- `assets/wokwi/wokwi_night.png`
- `assets/wokwi/wokwi_priority_ns.png`
- `assets/wokwi/wokwi_priority_ew.png`
- `assets/wokwi/wokwi_emergency.png`

## Recording Tips

- Keep the browser zoom stable before recording.
- Show the LCD in every screenshot because it proves the current mode/countdown.
- For video, record about 45-60 seconds: AUTO cycle, NIGHT, PRIORITY NS, PRIORITY EW, EMERGENCY.
- When using Windows, Snipping Tool video recording or Xbox Game Bar (`Win + Alt + R`) is enough for this project.
