#!/usr/bin/env python3
"""Mock backend for Flutter E2E screenshots.

Implements the minimum endpoints the Flutter app calls, returning realistic
shapes so the UI renders as if the real C# backend were up.

Endpoints implemented:
  GET  /api/health
  GET  /api/mqtt/status
  GET  /api/intersections/1/state
  GET  /api/intersections/1/approaches
  GET  /api/intersections/1/phase-plans/active
  GET  /api/intersections/1/phase-plans
  GET  /api/intersections/1/modes
  GET  /api/intersections/1/commands?limit=N
  GET  /api/intersections/1/logs?limit=N
  GET  /api/intersections/1/signals
  POST /api/intersections/1/commands
  POST /api/intersections/1/phase-plans
  POST /api/intersections/1/phase-plans/{id}/activate
  PUT  /api/intersections/1/phase-plans/{id}
  PUT  /api/intersections/1/approaches/{id}
  PUT  /api/intersections/1/signals/{id}
"""
import json
import time
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from datetime import datetime, timezone

# State held in memory (thread-safe for the demo)
state_lock = threading.RLock()
state = {
    "intersection_id": 1,
    "name": "Giao lộ mô phỏng",
    "current_mode": "AUTO",
    "current_phase": "NS_GREEN",
    "phase_countdown": 8,
    "mqtt_connected": True,
    "approaches": [
        {"id": 1, "code": "NORTH",     "name": "Hướng Bắc",   "enabled": True,  "signalCount": 3},
        {"id": 2, "code": "SOUTH",     "name": "Hướng Nam",   "enabled": True,  "signalCount": 3},
        {"id": 3, "code": "EAST",      "name": "Hướng Đông",  "enabled": True,  "signalCount": 3},
        {"id": 4, "code": "WEST",      "name": "Hướng Tây",   "enabled": True,  "signalCount": 3},
    ],
    "signals": [
        {"id": 1, "approachCode": "NORTH", "state": "GREEN",  "name": "Bắc - Xanh"},
        {"id": 2, "approachCode": "NORTH", "state": "YELLOW", "name": "Bắc - Vàng"},
        {"id": 3, "approachCode": "NORTH", "state": "RED",    "name": "Bắc - Đỏ"},
        {"id": 4, "approachCode": "SOUTH", "state": "GREEN",  "name": "Nam - Xanh"},
        {"id": 5, "approachCode": "SOUTH", "state": "YELLOW", "name": "Nam - Vàng"},
        {"id": 6, "approachCode": "SOUTH", "state": "RED",    "name": "Nam - Đỏ"},
        {"id": 7, "approachCode": "EAST",  "state": "RED",    "name": "Đông - Đỏ"},
        {"id": 8, "approachCode": "EAST",  "state": "RED",    "name": "Đông - Vàng"},
        {"id": 9, "approachCode": "EAST",  "state": "GREEN",  "name": "Đông - Xanh"},
        {"id": 10,"approachCode": "WEST",  "state": "RED",    "name": "Tây - Đỏ"},
        {"id": 11,"approachCode": "WEST",  "state": "RED",    "name": "Tây - Vàng"},
        {"id": 12,"approachCode": "WEST",  "state": "GREEN",  "name": "Tây - Xanh"},
    ],
    "phase_plans": [
        {
            "id": 1, "name": "Mặc định NS-Ưu tiên", "isActive": True,
            "greenSeconds": 8, "yellowSeconds": 3,
            "steps": [
                {"order": 1, "phase": "NS_GREEN",  "duration": 8},
                {"order": 2, "phase": "NS_YELLOW", "duration": 3},
                {"order": 3, "phase": "EW_GREEN",  "duration": 8},
                {"order": 4, "phase": "EW_YELLOW", "duration": 3},
            ],
        },
        {
            "id": 2, "name": "Phụ - Cân bằng", "isActive": False,
            "greenSeconds": 10, "yellowSeconds": 3,
            "steps": [
                {"order": 1, "phase": "NS_GREEN",  "duration": 10},
                {"order": 2, "phase": "NS_YELLOW", "duration": 3},
                {"order": 3, "phase": "EW_GREEN",  "duration": 10},
                {"order": 4, "phase": "EW_YELLOW", "duration": 3},
            ],
        },
    ],
    "modes": [
        {"code": "AUTO",        "name": "Tự động",    "priority": 0, "description": "Chu kỳ tự động"},
        {"code": "NIGHT",       "name": "Ban đêm",    "priority": 1, "description": "Giảm tốc độ ban đêm"},
        {"code": "PRIORITY_NS", "name": "Ưu tiên Bắc Nam", "priority": 5, "description": "Bắc Nam ưu tiên"},
        {"code": "PRIORITY_EW", "name": "Ưu tiên Đông Tây", "priority": 5, "description": "Đông Tây ưu tiên"},
        {"code": "EMERGENCY",   "name": "Khẩn cấp",  "priority": 10, "description": "Đèn đỏ nhấp nháy"},
    ],
    "commands": [
        {"id": 1, "command": "SET_AUTO",        "modeCode": "AUTO",        "source": "system", "createdBy": "seed",  "status": "applied",  "createdAt": "2026-06-19 09:00:00", "deviceStatus": "delivered"},
        {"id": 2, "command": "SET_NIGHT",       "modeCode": "NIGHT",       "source": "mobile", "createdBy": "hai",   "status": "applied",  "createdAt": "2026-06-19 09:05:00", "deviceStatus": "delivered"},
        {"id": 3, "command": "SET_PRIORITY_NS", "modeCode": "PRIORITY_NS", "source": "mobile", "createdBy": "hai",   "status": "applied",  "createdAt": "2026-06-19 09:10:00", "deviceStatus": "delivered"},
        {"id": 4, "command": "SET_EMERGENCY",   "modeCode": "EMERGENCY",   "source": "mobile", "createdBy": "hai",   "status": "applied",  "createdAt": "2026-06-19 09:15:00", "deviceStatus": "delivered"},
    ],
    "logs": [
        {"id": 1, "deviceId": "ESP32", "message": "Khởi động sketch",  "level": "info",  "timestamp": "2026-06-19T09:00:00Z"},
        {"id": 2, "deviceId": "ESP32", "message": "Kết nối MQTT broker", "level": "info",  "timestamp": "2026-06-19T09:00:02Z"},
        {"id": 3, "deviceId": "ESP32", "message": "MQTT msg: SET_AUTO",  "level": "info",  "timestamp": "2026-06-19T09:05:00Z"},
        {"id": 4, "deviceId": "ESP32", "message": "Publishing acks: command=SET_AUTO device=ESP32", "level": "info",  "timestamp": "2026-06-19T09:05:01Z"},
        {"id": 5, "deviceId": "ESP32", "message": "MQTT msg: SET_NIGHT", "level": "info",  "timestamp": "2026-06-19T09:05:10Z"},
        {"id": 6, "deviceId": "ESP32", "message": "Publishing acks: command=SET_NIGHT device=ESP32","level": "info",  "timestamp": "2026-06-19T09:05:11Z"},
    ],
    "next_command_id": 100,
}


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def now_sql():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def envelope(data=None, error=None):
    return json.dumps({"data": data, "error": error, "meta": {}}).encode("utf-8")


class MockHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Quieter logging
        print(f"[{time.strftime('%H:%M:%S')}] {self.address_string()} {fmt % args}")

    def _send_json(self, status, data=None, error=None):
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        body = envelope(data=data, error=error)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, status, msg):
        self._send_json(status, error={"code": status, "message": msg})

    def _read_body(self):
        n = int(self.headers.get("Content-Length", "0") or "0")
        if n == 0:
            return {}
        raw = self.rfile.read(n)
        try:
            return json.loads(raw.decode("utf-8"))
        except Exception:
            return {}

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        with state_lock:
            path = self.path.split("?")[0].rstrip("/")
            if path == "/api/health":
                self._send_json(200, {"status": "ok", "mqttConnected": state["mqtt_connected"], "version": "mock-1.0.0"})
            elif path == "/api/mqtt/status":
                self._send_json(200, {"broker": "broker.hivemq.com:1883", "connected": state["mqtt_connected"]})
            elif path == "/api/intersections/1/status":
                # Flutter bootstrap health probe — return compact status
                self._send_json(200, {
                    "intersectionId": 1,
                    "mode": state["current_mode"],
                    "phase": state["current_phase"],
                    "remainingSeconds": state["phase_countdown"],
                    "connected": state["mqtt_connected"],
                    "uptimeSeconds": 1234,
                })
            elif path == "/api/intersections/1/dashboard":
                # DashboardSnapshot shape: status, approaches, phasePlans, commands, logs, modes, deviceStatuses
                signals = [
                    {"approach": "NORTH", "signal": "RED",    "color": "red"},
                    {"approach": "NORTH", "signal": "YELLOW", "color": "yellow"},
                    {"approach": "NORTH", "signal": "GREEN",  "color": "green"},
                    {"approach": "SOUTH", "signal": "RED",    "color": "red"},
                    {"approach": "SOUTH", "signal": "YELLOW", "color": "yellow"},
                    {"approach": "SOUTH", "signal": "GREEN",  "color": "green"},
                    {"approach": "EAST",  "signal": "RED",    "color": "red"},
                    {"approach": "EAST",  "signal": "YELLOW", "color": "yellow"},
                    {"approach": "EAST",  "signal": "GREEN",  "color": "green"},
                    {"approach": "WEST",  "signal": "RED",    "color": "red"},
                    {"approach": "WEST",  "signal": "YELLOW", "color": "yellow"},
                    {"approach": "WEST",  "signal": "GREEN",  "color": "green"},
                ]
                self._send_json(200, {
                    "status": {
                        "modeCode": state["current_mode"],
                        "phaseCode": state["current_phase"],
                        "remainingSeconds": state["phase_countdown"],
                        "signals": signals,
                    },
                    "approaches": state["approaches"],
                    "phasePlans": state["phase_plans"],
                    "commands": state["commands"][:50],
                    "logs": state["logs"][:50],
                    "modes": state["modes"],
                    "deviceStatuses": [
                        {"id": "ESP32", "online": state["mqtt_connected"], "lastSeen": now_iso()}
                    ],
                })
            elif path == "/api/intersections/1/state":
                self._send_json(200, {
                    "intersectionId": 1,
                    "name": state["name"],
                    "currentMode": state["current_mode"],
                    "currentPhase": state["current_phase"],
                    "phaseCountdown": state["phase_countdown"],
                    "approaches": state["approaches"],
                    "signals": state["signals"],
                })
            elif path == "/api/intersections/1/approaches":
                self._send_json(200, state["approaches"])
            elif path == "/api/intersections/1/phase-plans/active":
                active = next((p for p in state["phase_plans"] if p["isActive"]), None)
                self._send_json(200, active or state["phase_plans"][0])
            elif path == "/api/intersections/1/phase-plans":
                self._send_json(200, state["phase_plans"])
            elif path == "/api/intersections/1/modes":
                self._send_json(200, state["modes"])
            elif path.startswith("/api/intersections/1/commands"):
                limit = 50
                if "?" in self.path:
                    qs = self.path.split("?", 1)[1]
                    for kv in qs.split("&"):
                        if kv.startswith("limit="):
                            try: limit = int(kv.split("=")[1])
                            except: pass
                self._send_json(200, state["commands"][:limit])
            elif path.startswith("/api/intersections/1/logs"):
                limit = 50
                if "?" in self.path:
                    qs = self.path.split("?", 1)[1]
                    for kv in qs.split("&"):
                        if kv.startswith("limit="):
                            try: limit = int(kv.split("=")[1])
                            except: pass
                self._send_json(200, state["logs"][:limit])
            elif path == "/api/intersections/1/signals":
                self._send_json(200, state["signals"])
            else:
                self._send_error(404, f"GET {path} not implemented in mock")

    def do_POST(self):
        with state_lock:
            path = self.path.split("?")[0].rstrip("/")
            body = self._read_body()
            if path == "/api/intersections/1/commands":
                cmd = (body.get("command") or "SET_AUTO").upper()
                mode_map = {
                    "SET_AUTO": "AUTO", "SET_NIGHT": "NIGHT",
                    "SET_PRIORITY_NS": "PRIORITY_NS", "SET_PRIORITY_EW": "PRIORITY_EW",
                    "SET_EMERGENCY": "EMERGENCY",
                }
                mode = body.get("modeCode") or mode_map.get(cmd, "AUTO")
                # Update current mode so dashboard reflects it
                state["current_mode"] = mode
                # Adjust signal pattern based on mode
                if mode == "EMERGENCY":
                    for s in state["signals"]:
                        s["state"] = "RED_BLINK"
                elif mode == "NIGHT":
                    for s in state["signals"]:
                        s["state"] = "YELLOW_BLINK"
                elif mode == "PRIORITY_NS":
                    for s in state["signals"]:
                        if s["approachCode"] in ("NORTH", "SOUTH"):
                            s["state"] = "GREEN"
                        else:
                            s["state"] = "RED"
                elif mode == "PRIORITY_EW":
                    for s in state["signals"]:
                        if s["approachCode"] in ("EAST", "WEST"):
                            s["state"] = "GREEN"
                        else:
                            s["state"] = "RED"
                else:  # AUTO
                    for s in state["signals"]:
                        if s["approachCode"] in ("NORTH", "SOUTH"):
                            s["state"] = "GREEN"
                        else:
                            s["state"] = "RED"
                cmd_id = state["next_command_id"]
                state["next_command_id"] += 1
                result = {
                    "id": cmd_id,
                    "command": cmd,
                    "modeCode": mode,
                    "source": body.get("source", "flutter"),
                    "createdBy": body.get("createdBy", "operator"),
                    "status": "queued",
                    "createdAt": now_sql(),
                    "deviceStatus": "queued",
                }
                state["commands"].insert(0, result)
                # Log it
                state["logs"].insert(0, {
                    "id": state["next_command_id"], "deviceId": "ESP32",
                    "message": f"MQTT msg: {cmd} mode={mode}", "level": "info", "timestamp": now_iso(),
                })
                self._send_json(201, result)
            elif path == "/api/intersections/1/phase-plans":
                self._send_json(201, {"id": 99, **body, "isActive": False})
            elif "/activate" in path:
                self._send_json(200, {"id": int(path.rsplit("/", 2)[-2]), "isActive": True, "activatedAt": now_iso()})
            else:
                self._send_error(404, f"POST {path} not implemented in mock")

    def do_PUT(self):
        with state_lock:
            path = self.path.split("?")[0].rstrip("/")
            body = self._read_body()
            if "/phase-plans/" in path:
                self._send_json(200, {"id": int(path.rsplit("/", 1)[-1]), **body, "updatedAt": now_iso()})
            elif "/approaches/" in path:
                appr_id = int(path.rsplit("/", 1)[-1])
                appr = next((a for a in state["approaches"] if a["id"] == appr_id), None)
                if appr:
                    appr.update(body)
                self._send_json(200, appr or {"id": appr_id, **body})
            elif "/signals/" in path:
                sig_id = int(path.rsplit("/", 1)[-1])
                sig = next((s for s in state["signals"] if s["id"] == sig_id), None)
                if sig:
                    sig.update(body)
                self._send_json(200, sig or {"id": sig_id, **body})
            else:
                self._send_error(404, f"PUT {path} not implemented in mock")


if __name__ == "__main__":
    port = 8000
    server = ThreadingHTTPServer(("127.0.0.1", port), MockHandler)
    print(f"[mock] listening on http://127.0.0.1:{port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
