import json
import os
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen

TSW_BASE = "http://127.0.0.1:31270"
BRIDGE_HOST = "0.0.0.0"
BRIDGE_PORT = 8080
POLL_SECONDS = 0.5

state = {
    "bridge": {"name": "Pure EBuLa Bridge", "version": "0.1.0"},
    "tsw": {"connected": False, "api": TSW_BASE, "game": None, "build": None},
    "train": {"number": None, "service": None, "route": None},
    "position": {"latitude": None, "longitude": None, "x": None, "y": None, "z": None, "kilometer": None},
    "direction": None,
    "simTime": None,
    "speed": None,
    "timestamp": None,
    "error": None,
}
lock = threading.Lock()
api_key = None
node_cache = []

def key_candidates():
    home = Path.home()
    docs = home / "Documents" / "My Games"
    return [
        docs / "TrainSimWorld6" / "Saved" / "Config" / "CommAPIKey.txt",
        docs / "TrainSimWorld6EGS" / "Saved" / "Config" / "CommAPIKey.txt",
        docs / "TrainSimWorld5" / "Saved" / "Config" / "CommAPIKey.txt",
        docs / "TrainSimWorld5EGS" / "Saved" / "Config" / "CommAPIKey.txt",
    ]

def find_api_key():
    for p in key_candidates():
        try:
            if p.exists():
                value = p.read_text(encoding="utf-8").strip()
                if value:
                    return value, str(p)
        except OSError:
            pass
    return None, None

def tsw_request(path, method="GET"):
    global api_key
    if not api_key:
        raise RuntimeError("CommAPIKey.txt nicht gefunden")
    url = TSW_BASE + path
    req = Request(url, method=method, headers={"DTGCommKey": api_key, "Accept": "application/json"})
    with urlopen(req, timeout=1.5) as response:
        raw = response.read().decode("utf-8", errors="replace")
        return json.loads(raw) if raw else {}

def flatten_nodes(value, prefix=""):
    result = []
    if isinstance(value, dict):
        for k, v in value.items():
            p = f"{prefix}.{k}" if prefix else str(k)
            result.extend(flatten_nodes(v, p))
    elif isinstance(value, list):
        for i, v in enumerate(value):
            result.extend(flatten_nodes(v, f"{prefix}.{i}"))
    else:
        result.append((prefix, value))
    return result

def discover():
    global node_cache
    data = tsw_request("/list")
    text = json.dumps(data, ensure_ascii=False)
    candidates = []
    for token in ("latitude", "longitude", "lat", "lon", "time", "timeofday", "position", "location", "speed", "formation", "player", "route"):
        if token in text.lower():
            candidates.append(token)
    node_cache = candidates
    return data

def first_matching_node(nodes, words):
    lowered = [(str(n).lower(), n) for n in nodes]
    for wordset in words:
        for low, original in lowered:
            if all(w in low for w in wordset):
                return original
    return None

def extract_node_names(data):
    names = []
    def walk(v):
        if isinstance(v, dict):
            for k, child in v.items():
                lk = str(k)
                if any(x in lk.lower() for x in ("latitude", "longitude", "lat", "lon", "time", "speed", "position", "location", "formation", "player", "route")):
                    names.append(lk)
                walk(child)
        elif isinstance(v, list):
            for child in v:
                walk(child)
    walk(data)
    return list(dict.fromkeys(names))

def safe_get(node):
    if not node:
        return None
    try:
        data = tsw_request("/get/" + quote(node, safe="/._-"))
        if isinstance(data, dict):
            for key in ("Value", "value", "Data", "data", "Result", "result"):
                if key in data:
                    return data[key]
        return data
    except Exception:
        return None

def poll_loop():
    global api_key, node_cache
    last_discovery = 0
    discovered = None
    while True:
        now = time.time()
        if not api_key:
            api_key, _ = find_api_key()
        if not api_key:
            with lock:
                state["tsw"]["connected"] = False
                state["error"] = "CommAPIKey.txt nicht gefunden"
            time.sleep(2)
            continue
        try:
            info = tsw_request("/info")
            with lock:
                state["tsw"]["connected"] = True
                meta = info.get("Meta", {}) if isinstance(info, dict) else {}
                state["tsw"]["game"] = meta.get("GameName")
                state["tsw"]["build"] = meta.get("GameBuildNumber")
                state["error"] = None
            if now - last_discovery > 10:
                try:
                    discovered = discover()
                    node_cache = extract_node_names(discovered)
                except Exception:
                    pass
                last_discovery = now

            names = node_cache
            lat_node = first_matching_node(names, [("latitude",), ("lat",)])
            lon_node = first_matching_node(names, [("longitude",), ("lon",)])
            time_node = first_matching_node(names, [("timeofday",), ("time",)])
            speed_node = first_matching_node(names, [("speed",)])

            lat = safe_get(lat_node)
            lon = safe_get(lon_node)
            sim_time = safe_get(time_node)
            speed = safe_get(speed_node)

            with lock:
                state["position"]["latitude"] = lat
                state["position"]["longitude"] = lon
                state["simTime"] = sim_time
                state["speed"] = speed
                state["timestamp"] = time.time()
        except Exception as exc:
            with lock:
                state["tsw"]["connected"] = False
                state["error"] = str(exc)
        time.sleep(POLL_SECONDS)

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def send_json(self, payload, status=200):
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        with lock:
            payload = json.loads(json.dumps(state))
        if self.path in ("/", "/api/status"):
            self.send_json(payload)
        elif self.path == "/api/state" or self.path == "/api/ebula":
            self.send_json(payload)
        elif self.path == "/api/position":
            self.send_json({"position": payload["position"], "direction": payload["direction"], "timestamp": payload["timestamp"]})
        elif self.path == "/api/time":
            self.send_json({"simTime": payload["simTime"], "timestamp": payload["timestamp"]})
        elif self.path == "/health":
            self.send_json({"ok": True, "tswConnected": payload["tsw"]["connected"]})
        else:
            self.send_json({"error": "not_found"}, 404)

def local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("192.0.2.1", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def main():
    print("Pure EBuLa Bridge")
    print("=================")
    print("TSW API: http://127.0.0.1:31270")
    print("Bridge:  http://%s:%d" % (local_ip(), BRIDGE_PORT))
    print("Suche CommAPIKey.txt automatisch...")
    global api_key
    api_key, path = find_api_key()
    if path:
        print("API-Key gefunden: " + path)
    else:
        print("API-Key noch nicht gefunden. TSW6 mit -HTTPAPI starten.")
    threading.Thread(target=poll_loop, daemon=True).start()
    server = ThreadingHTTPServer((BRIDGE_HOST, BRIDGE_PORT), Handler)
    print("Bridge läuft. Strg+C zum Beenden.")
    server.serve_forever()

if __name__ == "__main__":
    main()
