#!/usr/bin/env python3
"""Combined server: serve Flutter web + proxy /api → mock backend.

Avoids CORS by serving both on the same origin (:8080).
"""
import http.server
import http.client
import socketserver
import urllib.request
import urllib.error
import glob
import os
import threading
import sys

# WSL2 DrvFS path quirk: the real project lives behind the `Ta*` glob (no
# diacritics). Using a full diacritic path can land in a shadow inode that
# Python's os.path.isdir treats as non-existent. glob resolves it correctly.
_matches = glob.glob("/mnt/c/Users/hainx/OneDrive/Ta*/iot-traffic-light-wokwi/flutter_app/build/web")
FLUTTER_WEB_DIR = _matches[0] if _matches else "/tmp/no-such-folder"
print(f"[proxy] FLUTTER_WEB_DIR = {FLUTTER_WEB_DIR}", flush=True)
print(f"[proxy] exists = {os.path.isdir(FLUTTER_WEB_DIR)}", flush=True)
MOCK_BACKEND_HOST = "127.0.0.1"
MOCK_BACKEND_PORT = 8000
PORT = 8080


class CombinedHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # Some Python versions don't honor directory= in the parent when the
        # child only calls super().__init__ with a custom path. Fall back to
        # chdir so translate_path() resolves relative to the Flutter web dir.
        super().__init__(*args, directory=FLUTTER_WEB_DIR, **kwargs)

    def translate_path(self, path):
        # Force resolution against the Flutter web directory regardless of
        # what the parent __init__ stored.
        path = path.split("?", 1)[0].split("#", 1)[0]
        return os.path.join(FLUTTER_WEB_DIR, path.lstrip("/"))

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
        # CORS preflight
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _proxy(self, method, body):
        try:
            target_path = self.path
            upstream = http.client.HTTPConnection(MOCK_BACKEND_HOST, MOCK_BACKEND_PORT, timeout=10)
            headers = {"Content-Type": "application/json"}
            upstream.request(method, target_path, body=body, headers=headers)
            resp = upstream.getresponse()
            data = resp.read()
            self.send_response(resp.status)
            self.send_header("Content-Type", resp.getheader("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            err = f'{{"error":{{"code":502,"message":"proxy error: {e}"}}}}'.encode()
            self.send_header("Content-Length", str(len(err)))
            self.end_headers()
            self.wfile.write(err)


class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    # Start mock backend
    import subprocess
    mock_proc = subprocess.Popen(
        [sys.executable, "/tmp/mock_backend.py"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    print(f"[proxy] mock backend PID: {mock_proc.pid}", flush=True)

    # Wait for mock to be ready
    import time
    for _ in range(15):
        time.sleep(0.5)
        try:
            c = http.client.HTTPConnection("127.0.0.1", 8000, timeout=1)
            c.request("GET", "/api/health")
            r = c.getresponse()
            r.read()
            if r.status == 200:
                print("[proxy] mock backend ready", flush=True)
                break
        except Exception:
            pass

    server = ThreadedServer(("0.0.0.0", PORT), CombinedHandler)
    print(f"[proxy] serving Flutter web + /api proxy on http://0.0.0.0:{PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        mock_proc.terminate()
