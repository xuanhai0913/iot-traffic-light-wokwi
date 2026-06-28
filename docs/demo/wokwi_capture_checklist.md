# Wokwi Capture Checklist

Use this checklist when recording the final simulation evidence for report and slides.

## Before Recording

- [ ] Wokwi project has `sketch.ino`, `diagram.json`, and `libraries.txt` from the `wokwi/` folder.
- [ ] Simulation starts without compile/runtime errors.
- [ ] LCD is visible.
- [ ] NORTH, SOUTH, EAST, and WEST LED groups are visible.
- [ ] AUTO, NIGHT, PRIORITY, and EMERGENCY buttons are visible.
- [ ] Serial Monitor is open if using text commands.

## Screenshot List

| Step | Action | Expected evidence | Save as |
|---:|---|---|---|
| 1 | Start simulation in AUTO | LCD shows AUTO, one direction green and conflicting direction red | `docs/evidence/wokwi/wokwi_auto.png` |
| 2 | Press NIGHT or send `n` | Yellow warning blink / LCD NIGHT | `docs/evidence/wokwi/wokwi_night.png` |
| 3 | Send `p` or `priority_ns` | North/South green, East/West red | `docs/evidence/wokwi/wokwi_priority_ns.png` |
| 4 | Send `pe` or `priority_ew` | East/West green, North/South red | `docs/evidence/wokwi/wokwi_priority_ew.png` |
| 5 | Press EMERGENCY or send `e` | All directions red / LCD EMERGENCY | `docs/evidence/wokwi/wokwi_emergency.png` |

## Captured Evidence

Captured on 2026-06-15 from a Wokwi ESP32 simulator session loaded with the current repo files:

| Evidence | Status |
|---|---|
| `docs/evidence/wokwi/wokwi_compile_run.png` | Saved |
| `docs/evidence/wokwi/wokwi_auto.png` | Saved |
| `docs/evidence/wokwi/wokwi_night.png` | Saved |
| `docs/evidence/wokwi/wokwi_priority_ns.png` | Saved |
| `docs/evidence/wokwi/wokwi_priority_ew.png` | Saved |
| `docs/evidence/wokwi/wokwi_emergency.png` | Saved |

Backend command history confirmed `device_status=acknowledged` for command IDs 22-26: AUTO, NIGHT, PRIORITY_NS, PRIORITY_EW, and EMERGENCY.

## Video Script

Suggested video length: 45-60 seconds.

1. Start simulation and show AUTO for at least one visible phase change.
2. Press NIGHT or send `n`; wait until yellow blinking is obvious.
3. Send `p`; show PRIORITY NS.
4. Send `pe`; show PRIORITY EW.
5. Press EMERGENCY or send `e`; show all red.
6. Save as `demo/demo_wokwi.mp4`.

## Report Notes

Use this wording when explaining the upgraded Level 2 flow:

```text
Trong ban nang cap, Flutter app/web gui REST command den C# API.
C# API luu command vao SQLite va publish qua MQTT public broker.
ESP32/Wokwi subscribe command topic, doi den, roi publish ACK/status ve backend.
Button va Serial van duoc giu lam fallback khi WiFi/MQTT loi.
```
