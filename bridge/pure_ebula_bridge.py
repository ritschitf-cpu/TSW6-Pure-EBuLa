import json
import math
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, urlparse
from urllib.request import Request, urlopen

TSW_BASE = "http://127.0.0.1:31270"
BRIDGE_HOST = "0.0.0.0"
BRIDGE_PORT = 8080
POLL_SECONDS = 0.5

state = {
    "bridge": {"name": "Pure EBuLa Bridge", "version": "0.4.0"},
    "tsw": {
        "connected": False, "api": TSW_BASE, "game": None, "build": None,
        "routeHint": "", "vehicleId": None, "loco": None,
        "currentServiceName": None, "cameraMode": None, "inCab": False
    },
    "train": {"number": None, "service": None, "route": None},
    "position": {
        "latitude": None, "longitude": None, "x": None, "y": None, "z": None,
        "kilometer": None
    },
    "direction": None,
    "simTime": None,
    "speed": None,
    "trackData": None,
    "driverAid": None,
    "timestamp": None,
    "error": None,
    "recording": {"active": False, "samples": 0, "file": None, "started": None},
    "routeMatch": {"routeId": None, "routeName": None, "km": None, "distanceM": None, "point": None},
}
lock = threading.Lock()
api_key = None
record_lock = threading.Lock()
recording = False
record_samples = []
record_started = None
record_file = None
route_cache = []
route_cache_mtime = 0.0


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


def tsw_request(path):
    global api_key
    if not api_key:
        raise RuntimeError("CommAPIKey.txt nicht gefunden")
    req = Request(
        TSW_BASE + path,
        method="GET",
        headers={"DTGCommKey": api_key, "Accept": "application/json"},
    )
    with urlopen(req, timeout=2.0) as response:
        raw = response.read().decode("utf-8", errors="replace")
        return json.loads(raw) if raw else {}


def values(data):
    if not isinstance(data, dict):
        return data
    v = data.get("Values")
    if isinstance(v, dict):
        return v
    return data


def scalar(data, *keys):
    v = values(data)
    if isinstance(v, dict):
        for key in keys:
            if key in v and not isinstance(v[key], (dict, list)):
                return v[key]
            if key in v and isinstance(v[key], dict):
                inner = v[key]
                for inner_key in ("Value", "value", "LocalTimeISO8601", "WorldTimeISO8601"):
                    if inner_key in inner:
                        return inner[inner_key]
    return None


def first_number(data, keys):
    v = values(data)
    if isinstance(v, dict):
        for key in keys:
            x = v.get(key)
            if isinstance(x, (int, float)):
                return x
    return None


def safe_get(path):
    try:
        return tsw_request("/get/" + quote(path, safe="/._-"))
    except Exception:
        return None


def get_time():
    data = safe_get("TimeOfDay.Data")
    v = values(data)
    if isinstance(v, dict):
        return v.get("LocalTimeISO8601") or v.get("WorldTimeISO8601")
    return None


def get_position():
    # Preferred vehicle position, with PlayerInfo as a fallback.
    for endpoint in ("CurrentDrivableActor.LatLon", "DriverAid.PlayerInfo"):
        data = safe_get(endpoint)
        v = values(data)
        if not isinstance(v, dict):
            continue
        geo = v.get("geoLocation") if isinstance(v.get("geoLocation"), dict) else v
        lat = geo.get("latitude") if isinstance(geo, dict) else None
        lon = geo.get("longitude") if isinstance(geo, dict) else None
        if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
            return float(lat), float(lon), v
    return None, None, None


def get_speed():
    data = safe_get("CurrentDrivableActor.Function.HUD_GetSpeed")
    x = scalar(data, "Speed (ms)", "speed", "Speed")
    try:
        return float(x) * 3.6
    except (TypeError, ValueError):
        return None


def get_vehicle_id():
    data = safe_get("Timetable.VehicleID")
    v = values(data)
    if isinstance(v, dict):
        for k in ("VehicleID", "vehicleId", "Value", "value"):
            if k in v:
                return v[k]
    return v if isinstance(v, (str, int)) else None


def get_loco():
    data = safe_get("CurrentFormation/0.ObjectClass")
    v = scalar(data, "ObjectClass", "Value", "value")
    return str(v) if v is not None else None


def get_driver_aid():
    return safe_get("DriverAid.Data")


def get_track_data():
    # This endpoint is useful for upcoming markers, speed limits and positions.
    return safe_get("Player.Function.GetTrackData")


def player_field(player_info, *keys):
    if not isinstance(player_info, dict):
        return None
    for key in keys:
        value = player_info.get(key)
        if value is not None:
            return value
    return None


def detect_route_id(player_info, track_data, vehicle_id, loco):
    """
    Route identity for automatic timetable selection.
    For the first integration test we intentionally keep this conservative:
    Köln-Aachen is identified from live DriverAid station/marker names and
    the active service/vehicle context. No proprietary timetable data is used.
    """
    text = " ".join(str(x) for x in (player_info, track_data, vehicle_id, loco) if x is not None).lower()
    normalized = text.replace("ö", "o").replace("ä", "a").replace("ü", "u").replace("ß", "ss")
    signatures = (
        "aachen", "duren", "horrem", "eschweiler", "stolberg",
        "langerwehe", "merzenich", "sindorf", "koln ehrenfeld",
        "koln hbf", "koln hansaring", "frechen-konigsdorf",
    )
    hits = sum(1 for s in signatures if s in normalized)
    if hits >= 1:
        return "koeln-aachen"
    return None


def detect_in_cab(player_info, service_name):
    mode = str(player_field(player_info, "cameraMode", "CameraMode") or "").lower()
    if "driving" in mode or "cab" in mode or "fuehrerstand" in mode:
        return True
    # Some TSW states omit cameraMode briefly while the active service is already loaded.
    # currentServiceName + live geo is our short fallback during that transition.
    geo = player_info.get("geoLocation") if isinstance(player_info, dict) else None
    return bool(service_name and isinstance(geo, dict) and
                isinstance(geo.get("latitude"), (int, float)) and
                isinstance(geo.get("longitude"), (int, float)))


def route_hint(player_info, vehicle_id, loco):
    parts = []
    for obj in (player_info, vehicle_id, loco):
        if obj is not None:
            parts.append(str(obj))
    return " ".join(parts)


def route_distance_m(lat1,lon1,lat2,lon2):
    r=6371000.0
    p1=math.radians(lat1); p2=math.radians(lat2)
    dp=math.radians(lat2-lat1); dl=math.radians(lon2-lon1)
    h=math.sin(dp/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2*r*math.asin(math.sqrt(h))


def load_route_cache():
    global route_cache, route_cache_mtime
    directory=Path(__file__).resolve().parent/"routes"
    directory.mkdir(parents=True,exist_ok=True)
    try:
        latest=max((p.stat().st_mtime for p in directory.glob("*.json")),default=0.0)
    except OSError:
        latest=0.0
    if latest == route_cache_mtime:
        return route_cache
    loaded=[]
    for path in directory.glob("*.json"):
        try:
            data=json.loads(path.read_text(encoding="utf-8"))
            points=data.get("points",[])
            if isinstance(points,list) and len(points)>=2:
                loaded.append({"id":data.get("id",path.stem),"name":data.get("name",path.stem),"points":points})
        except (OSError,ValueError,TypeError):
            continue
    route_cache=loaded
    route_cache_mtime=latest
    return route_cache


def match_route(lat,lon):
    if lat is None or lon is None:
        return None
    best=None
    for route in load_route_cache():
        for point in route["points"]:
            try:
                plat=float(point["latitude"]); plon=float(point["longitude"])
                km=float(point["km"])
            except (KeyError,TypeError,ValueError):
                continue
            d=route_distance_m(lat,lon,plat,plon)
            if best is None or d < best["distanceM"]:
                best={"routeId":route["id"],"routeName":route["name"],"km":km,"distanceM":d,"point":point}
    return best


def record_sample(snapshot):
    global record_samples
    with record_lock:
        if not recording:
            return
        record_samples.append({
            "t": time.time(),
            "simTime": snapshot.get("simTime"),
            "latitude": snapshot.get("position", {}).get("latitude"),
            "longitude": snapshot.get("position", {}).get("longitude"),
            "speed": snapshot.get("speed"),
            "direction": snapshot.get("direction"),
            "vehicleId": snapshot.get("tsw", {}).get("vehicleId"),
            "loco": snapshot.get("tsw", {}).get("loco"),
            "routeHint": snapshot.get("tsw", {}).get("routeHint"),
            "trackData": snapshot.get("trackData"),
            "driverAid": snapshot.get("driverAid"),
        })


def start_recording():
    global recording, record_samples, record_started, record_file
    with record_lock:
        record_samples = []
        record_started = time.time()
        record_file = None
        recording = True
    with lock:
        state["recording"] = {"active": True, "samples": 0, "file": None, "started": record_started}


def stop_recording():
    global recording, record_file
    with record_lock:
        recording = False
        samples = list(record_samples)
        started = record_started
        if samples:
            out_dir = Path(__file__).resolve().parent / "recordings"
            out_dir.mkdir(parents=True, exist_ok=True)
            stamp = time.strftime("%Y%m%d-%H%M%S")
            path = out_dir / ("tsw6-route-%s.json" % stamp)
            payload = {
                "format": "pure-ebula-route-recording-v1",
                "started": started,
                "stopped": time.time(),
                "samples": samples,
            }
            path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
            record_file = str(path)
        else:
            record_file = None
    with lock:
        state["recording"] = {"active": False, "samples": len(samples), "file": record_file, "started": started}
    return record_file, len(samples)


def recording_snapshot():
    with record_lock:
        return {"active": recording, "samples": len(record_samples), "file": record_file, "started": record_started}


def poll_loop():
    global api_key
    while True:
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
            meta = info.get("Meta", {}) if isinstance(info, dict) else {}
            sim_time = get_time()
            player_info = safe_get("DriverAid.PlayerInfo")
            lat, lon, _ = get_position()
            speed = get_speed()
            vehicle_id = get_vehicle_id()
            loco = get_loco()
            aid = get_driver_aid()
            track = get_track_data()
            service_name = player_field(player_info, "currentServiceName", "CurrentServiceName")
            camera_mode = player_field(player_info, "cameraMode", "CameraMode")
            in_cab = detect_in_cab(player_info, service_name)
            detected_route = detect_route_id(player_info, track, vehicle_id, loco)

            matched = match_route(lat, lon)
            if detected_route:
                matched = matched or {"routeId": detected_route, "routeName": "Köln – Aachen", "km": None, "distanceM": None, "point": None}
                if matched.get("routeId") is None:
                    matched["routeId"] = detected_route
                    matched["routeName"] = "Köln – Aachen"
            with lock:
                state["tsw"]["connected"] = True
                state["tsw"]["game"] = meta.get("GameName")
                state["tsw"]["build"] = meta.get("GameBuildNumber")
                state["tsw"]["vehicleId"] = vehicle_id
                state["tsw"]["loco"] = loco
                state["tsw"]["currentServiceName"] = service_name
                state["tsw"]["cameraMode"] = camera_mode
                state["tsw"]["inCab"] = in_cab
                state["tsw"]["routeHint"] = route_hint(player_info, vehicle_id, loco)
                state["simTime"] = sim_time
                state["position"]["latitude"] = lat
                state["position"]["longitude"] = lon
                state["speed"] = speed
                state["driverAid"] = aid
                state["trackData"] = track
                state["timestamp"] = time.time()
                state["error"] = None
                state["routeMatch"] = matched or {"routeId": None, "routeName": None, "km": None, "distanceM": None, "point": None}
            with lock:
                snapshot = json.loads(json.dumps(state))
            record_sample(snapshot)
        except Exception as exc:
            with lock:
                state["tsw"]["connected"] = False
                state["error"] = str(exc)

        time.sleep(POLL_SECONDS)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def send_json(self, payload, status=200):
        raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
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

    def do_POST(self):
        path=urlparse(self.path).path
        if path == "/api/record/start":
            start_recording()
            self.send_json({"ok": True, "recording": recording_snapshot()})
            return
        if path == "/api/record/stop":
            file_path, samples = stop_recording()
            self.send_json({"ok": True, "recording": recording_snapshot(), "file": file_path, "samples": samples})
            return
        self.send_json({"error": "not_found"}, 404)

    def do_GET(self):
        with lock:
            payload = json.loads(json.dumps(state))
        if self.path in ("/", "/api/status", "/api/state", "/api/ebula"):
            self.send_json(payload)
        elif self.path == "/api/position":
            self.send_json({
                "position": payload["position"],
                "direction": payload["direction"],
                "timestamp": payload["timestamp"],
            })
        elif self.path == "/api/time":
            self.send_json({"simTime": payload["simTime"], "timestamp": payload["timestamp"]})
        elif self.path == "/health":
            self.send_json({
                "ok": True,
                "tswConnected": payload["tsw"]["connected"],
                "simTime": payload["simTime"],
                "positionLive": payload["position"]["latitude"] is not None and payload["position"]["longitude"] is not None,
                "speedLive": payload["speed"] is not None,
            })
        elif self.path == "/api/record/status":
            self.send_json({"recording": recording_snapshot(), "tsw": payload["tsw"], "position": payload["position"]})
        elif self.path == "/api/diagnostics":
            self.send_json({
                "tswConnected": payload["tsw"]["connected"],
                "apiKeyFound": api_key is not None,
                "positionLive": payload["position"]["latitude"] is not None and payload["position"]["longitude"] is not None,
                "latitude": payload["position"]["latitude"],
                "longitude": payload["position"]["longitude"],
                "simTime": payload["simTime"],
                "speed": payload["speed"],
                "vehicleId": payload["tsw"]["vehicleId"],
                "loco": payload["tsw"]["loco"],
                "currentServiceName": payload["tsw"]["currentServiceName"],
                "cameraMode": payload["tsw"]["cameraMode"],
                "inCab": payload["tsw"]["inCab"],
                "routeMatch": payload["routeMatch"],
                "routeHint": payload["tsw"]["routeHint"],
                "trackDataPresent": payload["trackData"] is not None,
                "driverAidPresent": payload["driverAid"] is not None,
                "recording": recording_snapshot(),
                "error": payload["error"],
            })
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
    print("Pure EBuLa Bridge 0.3")
    print("====================")
    print("TSW API: http://127.0.0.1:31270")
    print("Bridge:  http://%s:%d" % (local_ip(), BRIDGE_PORT))
    print("Recorder: POST /api/record/start  ->  /api/record/stop")
    print("TSW6 muss mit -HTTPAPI laufen.")
    print("Suche CommAPIKey.txt automatisch...")
    global api_key
    api_key, path = find_api_key()
    if path:
        print("API-Key gefunden: " + path)
    else:
        print("API-Key noch nicht gefunden.")
    threading.Thread(target=poll_loop, daemon=True).start()
    server = ThreadingHTTPServer((BRIDGE_HOST, BRIDGE_PORT), Handler)
    print("Bridge läuft. Strg+C zum Beenden.")
    server.serve_forever()


if __name__ == "__main__":
    main()
