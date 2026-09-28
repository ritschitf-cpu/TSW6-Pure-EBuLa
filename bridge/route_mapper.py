#!/usr/bin/env python3
"""Build a Pure EBuLa route geometry from a TSW6 recorder JSON."""
import argparse, json, math
from pathlib import Path

def haversine(a,b):
    lat1,lon1=a; lat2,lon2=b
    r=6371000.0
    p1,p2=math.radians(lat1),math.radians(lat2)
    dp=math.radians(lat2-lat1); dl=math.radians(lon2-lon1)
    h=math.sin(dp/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return 2*r*math.asin(math.sqrt(h))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("recording")
    ap.add_argument("--route-id",required=True)
    ap.add_argument("--name",required=True)
    ap.add_argument("--start-km",type=float,default=0.0)
    ap.add_argument("--end-km",type=float,default=None)
    ap.add_argument("--every",type=int,default=2)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()
    src=json.loads(Path(args.recording).read_text(encoding="utf-8"))
    raw=src.get("samples",[])
    pts=[]
    for s in raw:
        try: lat=float(s["latitude"]); lon=float(s["longitude"])
        except (KeyError,TypeError,ValueError): continue
        if not (-90<=lat<=90 and -180<=lon<=180): continue
        if pts and haversine((pts[-1]["lat"],pts[-1]["lon"]),(lat,lon)) < 0.5: continue
        pts.append({"lat":lat,"lon":lon})
    if len(pts)<2: raise SystemExit("Zu wenige gültige GPS-Punkte in der Aufnahme.")
    pts=pts[::max(1,args.every)]
    cumulative=[0.0]
    for i in range(1,len(pts)):
        cumulative.append(cumulative[-1]+haversine((pts[i-1]["lat"],pts[i-1]["lon"]),(pts[i]["lat"],pts[i]["lon"])))
    total=cumulative[-1]
    end_km=args.end_km if args.end_km is not None else args.start_km+total/1000.0
    if end_km <= args.start_km: raise SystemExit("--end-km muss größer als --start-km sein.")
    out=[]
    for p,d in zip(pts,cumulative):
        frac=d/total if total else 0
        out.append({"km":round(args.start_km+(end_km-args.start_km)*frac,4),"latitude":p["lat"],"longitude":p["lon"]})
    payload={"format":"pure-ebula-route-v1","id":args.route_id,"name":args.name,
             "source":"TSW6 HTTP API recording; kilometre calibration is user supplied","points":out}
    Path(args.output).parent.mkdir(parents=True,exist_ok=True)
    Path(args.output).write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"geschrieben: {args.output} · {len(out)} Punkte · {total/1000:.2f} km GPS")

if __name__=="__main__": main()
