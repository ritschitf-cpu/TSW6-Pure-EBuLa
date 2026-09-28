# Pure EBuLa route geometry

Route geometry is separate from timetable data.

## Create it from TSW6

1. Start TSW6 with -HTTPAPI and start bridge/pure_ebula_bridge.py.
2. Load the route/scenario.
3. Send POST /api/record/start to begin recording.
4. Drive the route in the desired direction.
5. Send POST /api/record/stop. The JSON recording is written to bridge/recordings/.
6. Convert it with bridge/route_mapper.py, for example:
   python bridge/route_mapper.py bridge/recordings/<file>.json --route-id koeln-aachen --name "Köln – Aachen" --start-km 0 --end-km 70.1 --output bridge/routes/koeln_aachen.json
7. Keep the generated route file in bridge/routes/. The bridge will use it for live route-km matching.

The start/end kilometre values are railway-kilometre calibration anchors. They must be checked against a suitable public route reference; GPS distance itself is not the official railway kilometre.

The architecture follows the public TSW HTTP API / GIS extraction concept used by TheJAG/tsw_connect. That project is MIT licensed; this repository does not copy its code or distribute proprietary TSW timetable data.
