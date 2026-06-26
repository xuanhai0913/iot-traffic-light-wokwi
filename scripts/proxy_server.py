#!/usr/bin/env python3
"""Serve Flutter web and proxy /api to the mock backend on one origin."""
import http.client
import http.server
import os
import socketserver
import subprocess
import sys
import time
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
FLUTTER_WEB_DIR = REPO_ROOT / "flutter_app" / "build" / "web"
MOCK_BACKEND = SCRIPT_DIR / "mock_backend.py"
MOCK_BACKEND_HOST = "127.0.0.1"
MOCK_BACKEND_PORT = 8000
PORT = int(os.environ.get("CAPTURE_PROXY_PORT", "8080"))

print(f"[proxy] FLUTTER_WEB_DIR = {FLUTTER_WEB_DIR}", flush=True)
print(f"[proxy] exists = {FLUTTER_WEB_DIR.is_dir()}", flush=True)


class CombinedHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(FLUTTER_WEB_DIR), **kwargs)

    def translate_path(self, path):
        path = path.split("?", 1)[0].split("#", 1)[0]
        return str(FLUTTER_WEB_DIR / path.lstrip("/"))

    def do_GET(self):
        if self.path.startswith("/api/") or self.path in ("/api", "/api/"):
            self._proxy("GET", None)
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/") or self.path in ("/api", "/api/"):
            length = int(self.headers.get("Content-Length", "0") or "0")
            body = self.rfile.read(length) if length > 0 else None
            self._proxy("POST", body)
        else:
            self.send_error(404)

    def do_PUT(self):
        if self.path.startswith("/api/") or self.path in ("/api", "/api/"):
            length = int(self.headers.get("Content-Length", "0") or "0")
            body = self.rfile.read(length) if length > 0 else None
            self._proxy("PUT", body)
        else:
            self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _proxy(self, method, body):
        try:
            upstream = http.client.HTTPConnection(MOCK_BACKEND_HOST, MOCK_BACKEND_PORT, timeout=10)
            upstream.request(method, self.path, body=body, headers={"Content-Type": "application/json"})
            resp = upstream.getresponse()
            data = resp.read()
            self.send_response(resp.status)
            self.send_header("Content-Type", resp.getheader("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        except Exception as exc:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            err = f'{{"error":{{"code":502,"message":"proxy error: {exc}"}}}}'.encode()
            self.send_header("Content-Length", str(len(err)))
            self.end_headers()
            self.wfile.write(err)


class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


def wait_for_mock():
    for _ in range(15):
        time.sleep(0.5)
        try:
            conn = http.client.HTTPConnection(MOCK_BACKEND_HOST, MOCK_BACKEND_PORT, timeout=1)
            conn.request("GET", "/api/health")
            resp = conn.getresponse()
            resp.read()
            if resp.status == 200:
                print("[proxy] mock backend ready", flush=True)
                return
        except Exception:
            pass
    raise RuntimeError("mock backend did not become ready")


if __name__ == "__main__":
    if not FLUTTER_WEB_DIR.is_dir():
        raise SystemExit(f"Flutter web build not found: {FLUTTER_WEB_DIR}")
    if not MOCK_BACKEND.is_file():
        raise SystemExit(f"Mock backend not found: {MOCK_BACKEND}")

    mock_proc = subprocess.Popen(
        [sys.executable, str(MOCK_BACKEND)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(f"[proxy] mock backend PID: {mock_proc.pid}", flush=True)

    try:
        wait_for_mock()
        server = ThreadedServer(("0.0.0.0", PORT), CombinedHandler)
        print(f"[proxy] serving Flutter web + /api proxy on http://0.0.0.0:{PORT}", flush=True)
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        mock_proc.terminate()
