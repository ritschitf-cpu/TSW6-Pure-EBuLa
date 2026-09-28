// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

part 'ebula_editor.dart';

void main() => runApp(const PureEBuLaApp());

class PureEBuLaApp extends StatelessWidget {
  const PureEBuLaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'EBuLa',
    theme: ThemeData(useMaterial3: false, fontFamily: 'monospace'),
    home: const SplashScreen(),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  Timer? timer;
  @override void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    timer = Timer(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const EBuLaScreen()));
    });
  }
  @override void dispose() { timer?.cancel(); pulse.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: FadeTransition(
      opacity: Tween<double>(begin: .28, end: 1).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
      child: const Text('EBuLa', style: TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.bold, letterSpacing: 5)),
    )),
  );
}

class StopPoint {
  final String name; final double km; final int? speed;
  final String? arrival; final String? departure; final String? note;
  final double? latitude; final double? longitude;
  final String? kind; final String? track;
  const StopPoint({
    required this.name, required this.km, this.speed, this.arrival, this.departure,
    this.note, this.latitude, this.longitude, this.kind, this.track,
  });
  factory StopPoint.fromJson(Map<String,dynamic> j) => StopPoint(
    name: (j['name'] ?? j['text'] ?? '') as String,
    km: ((j['km'] ?? 0) as num).toDouble(),
    speed: (j['speed'] as num?)?.toInt(),
    arrival: j['arrival'] as String?,
    departure: j['departure'] as String?,
    note: j['note'] as String?,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    kind: j['kind'] as String?,
    track: j['track'] as String?,
  );
  Map<String,dynamic> toJson()=> {
    'name':name,'km':km,'speed':speed,'arrival':arrival,'departure':departure,
    'note':note,'latitude':latitude,'longitude':longitude,'kind':kind,'track':track,
  }..removeWhere((k,v)=>v==null);
}

class TimetableData {
  final String id, trainNumber, service, serviceType, validity, date, vehicle;
  final List<String> serviceTypes;
  final int maxSpeed, lengthMeters, massTons;
  final String brakeHundredths, pzbType, notes;
  final List<StopPoint> stops;
  const TimetableData({
    required this.id, required this.trainNumber, required this.service, required this.serviceType,
    required this.validity, required this.date, required this.vehicle, required this.serviceTypes,
    required this.maxSpeed, required this.lengthMeters, required this.massTons,
    this.brakeHundredths='', this.pzbType='', this.notes='', required this.stops,
  });
  TimetableData withServiceType(String type)=>TimetableData(
    id:id,trainNumber:trainNumber,service:service,serviceType:type,validity:validity,date:date,
    vehicle:vehicle,maxSpeed:maxSpeed,lengthMeters:lengthMeters,massTons:massTons,
    brakeHundredths:brakeHundredths,pzbType:pzbType,notes:notes,stops:stops,serviceTypes:serviceTypes);
  factory TimetableData.fromJson(Map<String,dynamic> j) => TimetableData(
    id: j['id'] as String, trainNumber: j['trainNumber'] as String,
    service: j['service'] as String,
    serviceType: (j['serviceType'] as String?) ?? ((j['trainNumber'] as String).startsWith('ICE') ? 'ICE' : ((j['trainNumber'] as String).startsWith('IC') ? 'IC' : 'S-Bahn')),
    serviceTypes: (j['serviceTypes'] as List?)?.map((e)=>e.toString()).toList() ?? <String>[(j['serviceType'] as String?) ?? ((j['trainNumber'] as String).startsWith('ICE') ? 'ICE' : ((j['trainNumber'] as String).startsWith('IC') ? 'IC' : 'S-Bahn'))],
    validity: j['validity'] as String,
    date: j['date'] as String, vehicle: j['vehicle'] as String,
    maxSpeed: (j['maxSpeed'] as num?)?.toInt() ?? 0,
    lengthMeters: (j['lengthMeters'] as num?)?.toInt() ?? 0,
    massTons: (j['massTons'] as num?)?.toInt() ?? 0,
    brakeHundredths: (j['brakeHundredths'] ?? '').toString(),
    pzbType: (j['pzbType'] ?? '').toString(),
    notes: (j['notes'] ?? '').toString(),
    stops: (j['stops'] as List? ?? const []).map((e) => StopPoint.fromJson(e as Map<String,dynamic>)).toList(),
  );
}

class EBuLaScreen extends StatefulWidget {
  const EBuLaScreen({super.key});
  @override State<EBuLaScreen> createState() => _EBuLaScreenState();
}

class _EBuLaScreenState extends State<EBuLaScreen> {
  final files = const [
    'assets/timetables/ice15.json',
    'assets/timetables/bremen_oldenburg.json',
    'assets/timetables/stuttgart_heilbronn.json',
    'assets/timetables/koeln_aachen.json',
  ];
  List<TimetableData> all = [];
  TimetableData? train;
  Timer? clockTimer;
  DateTime clock = DateTime(2026,9,28,8,4,37);
  DateTime _lastRealTick = DateTime.now();
  int marker = 0, page = 0;
  bool paused=false, night=false, dark=false, fullscreen=false, opposite=false, markerPause=false, keyLights=false;
  String keyLightMode='orange';
  String overlay='';
  String panel='';
  String displayMode='time';
  final editorPanelKey=GlobalKey<EmbeddedEditorPanelState>();
  List<TimetableData> customTimetables=[];
  Map<String,dynamic> liveState={};
  Timer? liveTimer;
  double? liveLatitude, liveLongitude;
  String? liveSimTime;
  String liveRouteHint='';
  String bridgeHost='192.168.178.100';
  int bridgePort=8080;
  String bridgeStatus='Nicht verbunden';
  bool bridgeBusy=false;

  Color get bg => night ? const Color(0xff071018) : (dark ? const Color(0xff090b0c) : const Color(0xffeeeeee));
  Color get fg => night ? const Color(0xffc8dfff) : (dark ? Colors.white : const Color(0xff111111));
  Color get border => dark || night ? const Color(0xffd7d7d7) : const Color(0xff222222);
  Color get bar => night ? const Color(0xff172332) : (dark ? const Color(0xff24282a) : const Color(0xffd1d5d7));

  @override void initState() {
    super.initState();
    load();
    _lastRealTick = DateTime.now();
    liveTimer = Timer.periodic(const Duration(milliseconds: 600), (_) => pollBridge());
    clockTimer = Timer.periodic(const Duration(milliseconds:250), (_) {
      if (!paused && mounted) {
        final now = DateTime.now();
        final elapsed = now.difference(_lastRealTick);
        _lastRealTick = now;
        if (elapsed.inMilliseconds > 0) {
          setState(() {
            clock = clock.add(elapsed);
            if (displayMode=='time' && train!=null && train!.stops.isNotEmpty) {
              final nowText = clock.hour.toString().padLeft(2,'0')+':'+clock.minute.toString().padLeft(2,'0');
              for (var i=0; i<train!.stops.length; i++) {
                final t = train!.stops[i].arrival ?? train!.stops[i].departure;
                if (t != null && t == nowText) { marker=i; break; }
              }
            }
          });
        }
      } else {
        _lastRealTick = DateTime.now();
      }
    });
  }
  Future<void> load() async {
    final list=<TimetableData>[];
    for(final f in files) {
      try {
        final raw=await rootBundle.loadString(f);
        list.add(TimetableData.fromJson(jsonDecode(raw) as Map<String,dynamic>));
      } catch (_) {}
    }
    final prefs=await SharedPreferences.getInstance();
    final saved=prefs.getStringList('custom_timetables') ?? const <String>[];
    final customs=<TimetableData>[];
    for(final raw in saved) {
      try { customs.add(TimetableData.fromJson(jsonDecode(raw) as Map<String,dynamic>)); } catch (_) {}
    }
    if(!mounted) return;
    setState(() {
      customTimetables=customs;
      all=[...list,...customs];
      train=null;
      resetPosition();
    });
  }
  @override void dispose(){clockTimer?.cancel();liveTimer?.cancel();super.dispose();}
  void applyCustomTimetableState(TimetableData data,List<TimetableData> current){
    setState(() {
      customTimetables=current;
      final customIds=current.map((e)=>e.id).toSet();
      all=[...all.where((t)=>!customIds.contains(t.id)),...current];
      train=data;
      marker=0;
      page=0;
    });
  }


  Future<void> pollBridge() async {
    final host=bridgeHost.trim();
    if(host.isEmpty) return;
    try {
      final client=HttpClient()..connectionTimeout=const Duration(seconds:2);
      final req=await client.get(host, bridgePort, '/api/state');
      req.headers.set(HttpHeaders.acceptHeader,'application/json');
      final res=await req.close().timeout(const Duration(seconds:3));
      if(res.statusCode<200 || res.statusCode>=300) { client.close(force:true); return; }
      final raw=await res.transform(utf8.decoder).join();
      client.close(force:true);
      final data=jsonDecode(raw) as Map<String,dynamic>;
      final tsw=(data['tsw'] as Map?)?.cast<String,dynamic>() ?? {};
      final pos=(data['position'] as Map?)?.cast<String,dynamic>() ?? {};
      final sim=(data['simTime'] ?? '').toString();
      final lat=(pos['latitude'] as num?)?.toDouble();
      final lon=(pos['longitude'] as num?)?.toDouble();
      if(!mounted) return;
      setState(() {
        liveState=data;
        liveLatitude=lat;
        liveLongitude=lon;
        liveSimTime=sim.isEmpty || sim=='null' ? null : sim;
        liveRouteHint=(tsw['routeHint'] ?? '').toString();
        bridgeStatus=(tsw['connected']==true) ? 'Verbunden · TSW live' : 'Bridge verbunden · TSW wartet';
        if(liveSimTime!=null) {
          final dt=DateTime.tryParse(liveSimTime!.replaceFirst('Z','+00:00'))?.toLocal();
          if(dt!=null) clock=DateTime(clock.year,clock.month,clock.day,dt.hour,dt.minute,dt.second);
        }
        if(displayMode=='location' && liveLatitude!=null && liveLongitude!=null && train!=null) {
          final idx=nearestGeoIndex(train!.stops,liveLatitude!,liveLongitude!);
          if(idx!=null) marker=idx;
        } else if(displayMode=='time' && liveSimTime!=null && train!=null) {
          marker=markerForTime(liveSimTime!);
        }
      });
    } catch (_) {}
  }

  int markerForTime(String iso) {
    final dt=DateTime.tryParse(iso.replaceFirst('Z','+00:00'))?.toLocal();
    if(dt==null || train==null || train!.stops.isEmpty) return marker;
    final target=dt.hour*3600+dt.minute*60+dt.second;
    int best=0; var bestDiff=1<<30;
    for(var i=0;i<train!.stops.length;i++){
      final t=train!.stops[i].arrival ?? train!.stops[i].departure;
      if(t==null) continue;
      final p=t.split(':'); if(p.length<2) continue;
      final sec=(int.tryParse(p[0])??0)*3600+(int.tryParse(p[1])??0)*60;
      final diff=(sec-target).abs();
      if(diff<bestDiff){bestDiff=diff;best=i;}
    }
    return best;
  }

  int? nearestGeoIndex(List<StopPoint> stops,double lat,double lon){
    int? best; double bestD=double.infinity;
    for(var i=0;i<stops.length;i++){
      final p=stops[i];
      if(p.latitude==null || p.longitude==null) continue;
      final d=math.pow(p.latitude!-lat,2)+math.pow(p.longitude!-lon,2);
      if(d<bestD){bestD=d.toDouble();best=i;}
    }
    return best;
  }

  void resetPosition(){
    marker=0; page=0; markerPause=false;
    if(train != null && train!.stops.isNotEmpty){
      final t=train!.stops.first.departure ?? train!.stops.first.arrival;
      if(t != null){
        final p=t.split(':');
        if(p.length==2) clock=DateTime(clock.year,clock.month,clock.day,int.tryParse(p[0])??clock.hour,int.tryParse(p[1])??clock.minute,0);
      }
    }
  }
  String clockText()=>clock.hour.toString().padLeft(2,'0')+':'+clock.minute.toString().padLeft(2,'0')+':'+clock.second.toString().padLeft(2,'0');
  StopPoint? get point => train==null || train!.stops.isEmpty ? null : train!.stops[marker];
  void move(int d){
    if(train==null) return;
    setState(()=>marker=(marker+d).clamp(0,train!.stops.length-1).toInt());
  }
  void pageMove(int d){
    if(train==null) return;
    setState(()=>page=(page+d*8).clamp(0,train!.stops.length-1).toInt());
  }
  void adjust(int s)=>setState(()=>clock=clock.add(Duration(seconds:s)));

  void action(String a){
    if(a=='G'){setState(()=>{overlay='',panel=''}); return;}
    if(a=='aus'){setState(()=>panel='system');}
    else if(a=='Zug'){setState(()=>panel='train');}
    else if(a=='FSD'){setState(()=>panel='route');}
    else if(a=='GW'){setState(()=>opposite=!opposite);}
    else if(a=='Zeit'){setState(()=>panel='mode');}
    else if(a=='S'){setState(() { paused=!paused; _lastRealTick=DateTime.now(); });}
    else if(a=='I'){setState(()=>panel='keylight');}
    else if(a=='St'){setState(()=>panel='bridge');}
    else if(a=='-5s'){adjust(-5);}
    else if(a=='+5s'){adjust(5);}
    else if(a=='Tag/Nacht'){setState(()=>night=!night);}
    else if(a=='Hell/Dunkel'){setState(()=>dark=!dark);}
    else if(a=='UD'){
      setState(()=>fullscreen=!fullscreen);
      SystemChrome.setEnabledSystemUIMode(fullscreen?SystemUiMode.immersiveSticky:SystemUiMode.edgeToEdge);
    }
    else if(a=='▲'){move(-1);}
    else if(a=='▼'){move(1);}
    else if(a=='⯇'){pageMove(-1);}
    else if(a=='⯈'){pageMove(1);}
    else if(a=='E'){if(panel=='editor'){editorPanelKey.currentState?.save();}else if(panel.isNotEmpty){setState(()=>panel='');}else{setState(()=>markerPause=!markerPause);}}
    else if(a=='C'){if(panel.isNotEmpty){setState(()=>panel='');}else{setState(()=>overlay='');}}
  }

  void showTrain(){
    showDialog(context:context, barrierColor:Colors.black87, builder:(_)=>Dialog(
      backgroundColor:const Color(0xff17191a),
      insetPadding:const EdgeInsets.all(18),
      child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:820,maxHeight:540),
        child:Column(children:[
          Container(height:44,color:const Color(0xff34393c),padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
            const Text('EBuLa – Zugauswahl',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:17)),
            const Spacer(),Text('E = übernehmen   C = abbrechen',style:TextStyle(color:Colors.white70,fontSize:11)),
          ])),
          Expanded(child:ListView(
            padding:const EdgeInsets.all(8),
            children:[
              for(final t in all)
                for(final type in t.serviceTypes)
                  InkWell(
                    onTap:(){setState(() { train=t.withServiceType(type); resetPosition(); overlay=''; });Navigator.pop(context);},
                    child:Container(
                      margin:const EdgeInsets.only(bottom:6),
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),
                      decoration:BoxDecoration(
                        color:(train?.id==t.id && train?.serviceType==type)?const Color(0xff53616a):const Color(0xff24282a),
                        border:Border.all(color:(train?.id==t.id && train?.serviceType==type)?Colors.white:const Color(0xff62696d)),
                      ),
                      child:Row(children:[
                        SizedBox(width:92,child:Text(t.trainNumber,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16))),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(type+'  ·  '+t.service,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
                          Text(t.vehicle+'   Vmax '+t.maxSpeed.toString()+' km/h   '+t.validity,style:const TextStyle(color:Colors.white70,fontSize:10)),
                        ])),
                        if(train?.id==t.id && train?.serviceType==type) const Icon(Icons.check,color:Colors.white),
                      ]),
                    ),
                  ),
            ],
          )),
          Container(height:34,color:const Color(0xff25292b),padding:const EdgeInsets.symmetric(horizontal:10),child:const Align(
            alignment:Alignment.centerLeft,child:Text('Demo-/Beispieldaten – eigene Testfahrpläne',style:TextStyle(color:Colors.white60,fontSize:10)),
          )),
        ]),
      ),
    ));
  }

  Future<void> connectBridge() async {
    final host=bridgeHost.trim();
    if(host.isEmpty) return;
    setState(() { bridgeBusy=true; bridgeStatus='Verbinde …'; });
    try {
      final client=HttpClient();
      client.connectionTimeout=const Duration(seconds:3);
      final req=await client.get(host, bridgePort, '/api/state');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res=await req.close().timeout(const Duration(seconds:4));
      final body=await res.transform(utf8.decoder).join();
      client.close(force:true);
      if(res.statusCode<200 || res.statusCode>=300) throw Exception('HTTP ${res.statusCode}');
      if(!mounted) return;
      final data=jsonDecode(body) as Map<String,dynamic>;
      final tsw=(data['tsw'] as Map?)?.cast<String,dynamic>() ?? {};
      setState(() { bridgeBusy=false; bridgeStatus=tsw['connected']==true ? 'Verbunden · TSW live' : 'Verbunden · TSW wartet'; });
    } catch (_) {
      if(!mounted) return;
      setState(() { bridgeBusy=false; bridgeStatus='Nicht erreichbar'; });
    }
  }

  void showBridge(){
    final hostCtrl=TextEditingController(text:bridgeHost);
    final portCtrl=TextEditingController(text:bridgePort.toString());
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(
      backgroundColor:const Color(0xff202426),
      title:const Text('St – TSW6 Bridge',style:TextStyle(color:Colors.white)),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        const Align(alignment:Alignment.centerLeft,child:Text('Bridge / API-Adresse',style:TextStyle(color:Colors.white70,fontSize:11))),
        const SizedBox(height:4),
        TextField(controller:hostCtrl,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(labelText:'IP / Hostname',labelStyle:TextStyle(color:Colors.white70),enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:Colors.white38)),focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:Color(0xfff0a13a))))),
        const SizedBox(height:8),
        TextField(controller:portCtrl,keyboardType:TextInputType.number,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(labelText:'Port',labelStyle:TextStyle(color:Colors.white70),enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:Colors.white38)),focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:Color(0xfff0a13a))))),
        const SizedBox(height:12),
        Align(alignment:Alignment.centerLeft,child:Text('Status: $bridgeStatus',style:TextStyle(color:bridgeStatus=='Verbunden'?Colors.greenAccent:Colors.white70,fontSize:11))),
        const SizedBox(height:5),
        const Align(alignment:Alignment.centerLeft,child:Text('Bridge-Schicht vorbereitet für TSW6-Positions-, Richtungs- und Zeitdaten.',style:TextStyle(color:Colors.white54,fontSize:9))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('C')),
        TextButton(onPressed:bridgeBusy?null:() async {
          final p=int.tryParse(portCtrl.text.trim())??8080;
          setState(() { bridgeHost=hostCtrl.text.trim(); bridgePort=p; });
          await connectBridge();
          setLocal((){});
        },child:const Text('VERBINDEN')),
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('E')),
      ],
    )));
  }

  void showKeyLightSettings(){
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(
      backgroundColor:const Color(0xff202426),
      title:const Text('Tastenbeleuchtung',style:TextStyle(color:Colors.white)),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        RadioListTile<String>(value:'off',groupValue:keyLightMode,title:const Text('Aus',style:TextStyle(color:Colors.white)),onChanged:(v){setLocal(()=>keyLightMode=v!);setState((){});}),
        RadioListTile<String>(value:'orange',groupValue:keyLightMode,title:const Text('Orange',style:TextStyle(color:Colors.white)),onChanged:(v){setLocal(()=>keyLightMode=v!);setState((){});}),
        RadioListTile<String>(value:'yellow',groupValue:keyLightMode,title:const Text('Gelb',style:TextStyle(color:Colors.white)),onChanged:(v){setLocal(()=>keyLightMode=v!);setState((){});}),
        RadioListTile<String>(value:'auto',groupValue:keyLightMode,title:const Text('Automatisch',style:TextStyle(color:Colors.white)),onChanged:(v){setLocal(()=>keyLightMode=v!);setState((){});}),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('E',style:TextStyle(color:Color(0xfff0b15b))))],
    )));
  }

  Color get keyGlow {
    if(keyLightMode=='yellow') return const Color(0xffffd35a);
    if(keyLightMode=='orange') return const Color(0xfff0a13a);
    if(keyLightMode=='auto') return night ? const Color(0xffffc65a) : const Color(0xfff0a13a);
    return const Color(0xff3c3c3c);
  }

  void showTime(){
    int h=clock.hour,m=clock.minute;
    String mode=displayMode;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(
      backgroundColor:const Color(0xff202426),
      title:const Text('Zeit / Anzeigepunkt',style:TextStyle(color:Colors.white)),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          TextButton(onPressed:()=>setLocal(()=>h=(h+23)%24),child:const Text('-',style:TextStyle(color:Colors.white,fontSize:24))),
          Text(h.toString().padLeft(2,'0'),style:const TextStyle(color:Colors.white,fontSize:28)),
          TextButton(onPressed:()=>setLocal(()=>h=(h+1)%24),child:const Text('+',style:TextStyle(color:Colors.white,fontSize:24))),
          const Text(':',style:TextStyle(color:Colors.white,fontSize:28)),
          TextButton(onPressed:()=>setLocal(()=>m=(m+59)%60),child:const Text('-',style:TextStyle(color:Colors.white,fontSize:24))),
          Text(m.toString().padLeft(2,'0'),style:const TextStyle(color:Colors.white,fontSize:28)),
          TextButton(onPressed:()=>setLocal(()=>m=(m+1)%60),child:const Text('+',style:TextStyle(color:Colors.white,fontSize:24))),
        ]),
        const Divider(color:Colors.white24),
        RadioListTile<String>(value:'manual',groupValue:mode,title:const Text('Manuell',style:TextStyle(color:Colors.white)),subtitle:const Text('Punkt mit ▲ / ▼ bewegen',style:TextStyle(color:Colors.white54)),onChanged:(v)=>setLocal(()=>mode=v!)),
        RadioListTile<String>(value:'time',groupValue:mode,title:const Text('Per Zeit',style:TextStyle(color:Colors.white)),subtitle:const Text('Anzeigepunkt läuft mit der Fahrplanzeit',style:TextStyle(color:Colors.white54)),onChanged:(v)=>setLocal(()=>mode=v!)),
        RadioListTile<String>(value:'location',groupValue:mode,title:const Text('Per Ortung',style:TextStyle(color:Colors.white)),subtitle:const Text('Später über TSW6-Bridge / Position',style:TextStyle(color:Colors.white54)),onChanged:(v)=>setLocal(()=>mode=v!)),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('C')),
        TextButton(onPressed:(){setState(()=>displayMode=mode);setState(()=>clock=DateTime(clock.year,clock.month,clock.day,h,m,clock.second));Navigator.pop(context);},child:const Text('E')),
      ],
    )));
  }

  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor:Colors.black,body:SafeArea(child:Center(
      child:AspectRatio(aspectRatio:4/3,child:monitor()),
    )));
  }

  Widget monitor()=>Container(
    decoration:BoxDecoration(color:const Color(0xff090909),border:Border.all(color:const Color(0xff3e4244),width:5),boxShadow:const[BoxShadow(color:Colors.black,blurRadius:14,spreadRadius:3)]),
    child:Column(children:[topKeys(),Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(9,4,9,3),child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:screen()),const SizedBox(width:6),sideKeys()]))),bottomKeys()]),
  );

  Widget topKeys(){
    const labels=['aus','S','i','St','-5s','+5s','✸','◑','UD'];
    return Container(height:49,color:const Color(0xff101010),padding:const EdgeInsets.fromLTRB(10,7,10,4),child:Row(
      children:labels.map((l)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:physicalKey(l,()=>action(
        l=='S'?'S':l=='i'?'I':l=='St'?'St':l=='-5s'?'-5s':l=='+5s'?'+5s':l=='✸'?'Tag/Nacht':l=='◑'?'Hell/Dunkel':l=='UD'?'UD':''
      ))))).toList(),
    ));
  }

  Widget sideKeys()=>SizedBox(width:58,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    sideKey('▲','▲'),const SizedBox(height:5),
    sideKey('E','E'),const SizedBox(height:5),
    sideKey('<','⯇'),const SizedBox(height:5),
    sideKey('>','⯈'),const SizedBox(height:5),
    sideKey('C','C'),const SizedBox(height:5),
    sideKey('▼','▼'),
  ]));
  Widget sideKey(String label,String actionName)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(vertical:1),child:InkWell(onTap:()=>action(actionName),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xff080808),border:Border.all(color:keyGlow,width:keyLightMode=='off'?1:2),borderRadius:BorderRadius.circular(3)),child:Text(label,style:TextStyle(color:keyGlow,fontSize:22,fontWeight:FontWeight.bold))))));
  Widget bottomKeys(){
    const labels=['Zug','FSD','','▲','▼','GW','Zeit','','','G'];
    const numbers=['1','2','3','4','5','6','7','8','9','0'];
    return Container(height:55,color:const Color(0xff0d0d0d),padding:const EdgeInsets.fromLTRB(9,2,9,6),child:Row(
      children:List.generate(10,(i)=>Expanded(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:2),
        child:physicalFunctionKey(labels[i],numbers[i],labels[i].isEmpty?null:()=>action(labels[i])),
      ))),
    ));
  }

  Widget physicalFunctionKey(String label,String number,VoidCallback? onTap)=>SizedBox(
    height:43,
    child:InkWell(onTap:onTap,child:Container(
      alignment:Alignment.center,
      decoration:BoxDecoration(color:const Color(0xff080808),border:Border.all(color:keyGlow,width:keyLightMode=='off'?1.0:1.5),borderRadius:BorderRadius.circular(3)),
      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        Text(label,style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold,fontSize:10)),
        const SizedBox(height:1),
        Text(number,style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold,fontSize:8)),
      ]),
    )),
  );

  Widget physicalKey(String text,VoidCallback onTap)=>SizedBox(height:34,child:InkWell(onTap:onTap,child:Container(
    alignment:Alignment.center,
    decoration:BoxDecoration(color:const Color(0xff080808),border:Border.all(color:keyGlow,width:keyLightMode=='off'?1.0:2.0),borderRadius:BorderRadius.circular(3),boxShadow:keyLightMode=='off'?const []:[BoxShadow(color:Color(0x66f0a13a),blurRadius:5,spreadRadius:.3)]),
    child:Text(text,style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold,fontSize:12,shadows:keyLightMode=='off'?const []:[Shadow(color:keyGlow,blurRadius:4)])),
  )));

  Widget screen(){
    final list=train?.stops.skip(page).take(10).toList() ?? const <StopPoint>[];
    return Stack(children:[
      Container(
        decoration:BoxDecoration(color:bg,border:Border.all(color:border,width:1)),
        child:Column(children:[header(),routeBar(),table(list),status()]),
      ),
      if(overlay=='FSD') fsdOverlay(),
      if(panel.isNotEmpty) Positioned.fill(child:ebulaPanel()),
    ]);
  }

  Widget header()=>SizedBox(height:42,child:Row(children:[
    headerCell(train?.trainNumber??'',18,17),
    headerCell(train?.service??'',40,16),
    headerCell(train?.date??'',18,13),
    headerCell(clockText(),18,16,red:paused),
  ]));

  Widget headerCell(String text,int flex,double size,{bool red=false})=>Expanded(flex:flex,child:Container(
    alignment:Alignment.center,decoration:BoxDecoration(border:Border.all(color:border)),
    child:FittedBox(fit:BoxFit.scaleDown,child:Text(text,style:TextStyle(color:red?const Color(0xffb00000):fg,fontWeight:FontWeight.bold,fontSize:size))),
  ));

  Widget routeBar()=>SizedBox(height:27,child:Row(children:[
    Expanded(flex:18,child:Container(alignment:Alignment.centerLeft,padding:const EdgeInsets.symmetric(horizontal:5),decoration:BoxDecoration(border:Border.all(color:border)),child:Text(point?.speed==null?'':'ab km '+(point?.km.toStringAsFixed(1)??'')+': '+point!.speed.toString()+' km/h',style:TextStyle(color:fg,fontSize:10,fontWeight:FontWeight.bold)))),
    Expanded(flex:62,child:Container(decoration:BoxDecoration(border:Border.all(color:border)))),
    Expanded(flex:20,child:Container(alignment:Alignment.center,padding:const EdgeInsets.symmetric(horizontal:4),decoration:BoxDecoration(border:Border.all(color:border)),child:Text(train==null?'Nächster Halt:':'Nächster Halt: '+(point?.name??''),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:10,fontWeight:FontWeight.bold)))),
  ]));

  Widget table(List<StopPoint> rows)=>Expanded(child:ListView.builder(
    itemCount:rows.length,
    itemBuilder:(_,i){
      final p=rows[i], active=page+i==marker;
      return SizedBox(height:48,child:Row(children:[
        Expanded(flex:14,child:Container(
          decoration:BoxDecoration(border:Border(right:BorderSide(color:border,width:1))),
          child:Stack(children:[
            Center(child:Text(p.speed?.toString()??'',style:TextStyle(color:fg,fontSize:12,fontWeight:FontWeight.bold))),
            if(active) Align(alignment:Alignment.centerRight,child:CustomPaint(size:const Size(12,12),painter:MarkerDiamondPainter(color:fg))),
          ]),
        )),
        Expanded(flex:13,child:Container(alignment:Alignment.center,decoration:BoxDecoration(border:Border(right:BorderSide(color:border,width:1))),child:Text(p.km.toStringAsFixed(1).replaceAll('.',','),style:TextStyle(color:fg,fontSize:12)))),
        Expanded(flex:43,child:Container(
          alignment:Alignment.centerLeft,padding:const EdgeInsets.symmetric(horizontal:7),
          decoration:BoxDecoration(border:Border(right:BorderSide(color:border,width:1))),
          child:Row(children:[
            if(p.kind!=null) Padding(padding:const EdgeInsets.only(right:5),child:Text(p.kind!,style:TextStyle(color:fg,fontSize:10,fontWeight:FontWeight.bold))),
            Expanded(child:Text(p.note??p.name,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:11,fontWeight:active?FontWeight.bold:FontWeight.normal))),
          ]),
        )),
        Expanded(flex:15,child:Container(alignment:Alignment.center,decoration:BoxDecoration(border:Border(right:BorderSide(color:border,width:1))),child:Text(p.arrival??'',style:TextStyle(color:fg,fontSize:11)))),
        Expanded(flex:15,child:Container(alignment:Alignment.center,child:Text(p.departure??'',style:TextStyle(color:fg,fontSize:11)))),
      ]));
    },
  ));

  Widget status()=>Container(height:25,color:night?const Color(0xff172332):(dark?const Color(0xff252a2d):const Color(0xffefede5)),padding:const EdgeInsets.symmetric(horizontal:5),child:Row(children:[
    Text(displayMode=='location'?'Ortung':displayMode=='time'?'Zeit':'manuell',style:TextStyle(color:fg,fontSize:10)),
    const Spacer(),
    Text(opposite?'RW / l':'RW / r',style:TextStyle(color:fg,fontSize:10)),
    const SizedBox(width:16),Text('600 A',style:TextStyle(color:fg,fontSize:10)),
    const SizedBox(width:16),Text('GSM-R',style:TextStyle(color:fg,fontSize:10)),
    const SizedBox(width:16),Text(delayText(),style:TextStyle(color:fg,fontSize:10)),
    const SizedBox(width:16),Text('ESF',style:TextStyle(color:fg,fontSize:10)),
    const SizedBox(width:10),Text('+ 0 kWh',style:TextStyle(color:fg,fontSize:10)),
    const SizedBox(width:10),Text('- 0 kWh',style:TextStyle(color:fg,fontSize:10)),
  ]));

  String delayText(){
    if(train==null || liveSimTime==null) return '0 min';
    final dt=DateTime.tryParse(liveSimTime!.replaceFirst('Z','+00:00'))?.toLocal();
    final p=point;
    if(dt==null || p==null) return '0 min';
    final t=p.arrival ?? p.departure; if(t==null) return '0 min';
    final q=t.split(':'); if(q.length<2) return '0 min';
    final scheduled=(int.tryParse(q[0])??0)*60+(int.tryParse(q[1])??0);
    final actual=dt.hour*60+dt.minute;
    final d=actual-scheduled;
    return (d>=0?'+':'')+d.toString()+' min';
  }

  Widget fsdOverlay()=>Positioned.fill(
    child:Container(
      color:const Color(0xf20b0d0e),
      padding:const EdgeInsets.all(14),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Text('FSD – Fahrplan- und Streckendaten',style:const TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.bold)),
          const Spacer(),
          InkWell(onTap:()=>setState(()=>overlay=''),child:Container(
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),
            decoration:BoxDecoration(color:Colors.black,border:Border.all(color:const Color(0xffd08a35))),
            child:const Text('C',style:TextStyle(color:Color(0xfff0b15b),fontWeight:FontWeight.bold)),
          )),
        ]),
        const SizedBox(height:8),
        Text('Zug: '+(train?.trainNumber??'---')+'    Typ: '+(train?.serviceType??'---')+'    Strecke: '+(train?.service??''),
          style:const TextStyle(color:Colors.white,fontSize:11)),
        Text('Fahrzeug: '+(train?.vehicle??'---')+'    Masse: '+(train?.massTons.toString()??'--')+' t    Länge: '+(train?.lengthMeters.toString()??'--')+' m    Vmax: '+(train?.maxSpeed.toString()??'--')+' km/h',
          style:const TextStyle(color:Colors.white,fontSize:11)),
        const SizedBox(height:7),
        Expanded(child:ListView(
          children:(train?.stops??const <StopPoint>[]).map((p)=>Padding(
            padding:const EdgeInsets.symmetric(vertical:2),
            child:Text(
              p.km.toStringAsFixed(1).padLeft(6)+'   '+(p.note??p.name).padRight(25)+'   '+(p.arrival??'--:--')+'   '+(p.departure??'--:--'),
              style:const TextStyle(color:Colors.white,fontSize:10),
            ),
          )).toList(),
        )),
      ]),
    ),
  );



  Widget ebulaPanel(){
    final titles=<String,String>{
      'system':'System / Fahrplan','train':'Zugauswahl','mode':'Zeit / Anzeigepunkt',
      'bridge':'St – TSW6 Bridge','keylight':'i – Tastenbeleuchtung',
      'route':'FSD – Strecken-/Fahrplandaten','editor':'aus – Fahrplan programmieren'
    };
    return Container(
      color:Colors.black54,
      padding:const EdgeInsets.all(14),
      child:Container(
        decoration:BoxDecoration(color:bg,border:Border.all(color:border,width:2),boxShadow:const[BoxShadow(color:Colors.black54,blurRadius:10)]),
        child:Column(children:[
          Container(height:38,color:bar,padding:const EdgeInsets.symmetric(horizontal:10),child:Row(children:[
            Text(titles[panel]??'EBuLa',style:TextStyle(color:fg,fontWeight:FontWeight.bold,fontSize:14)),
            const Spacer(),Text('E = übernehmen   C = zurück',style:TextStyle(color:fg,fontSize:9))
          ])),
          Expanded(child:_panelBody()),
          Container(height:35,color:bar,padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[
            Text('EBuLa-Systemfenster',style:TextStyle(color:fg,fontSize:9)),
            const Spacer(),
            TextButton(onPressed:()=>action('C'),child:Text('C',style:TextStyle(color:fg,fontWeight:FontWeight.bold))),
            TextButton(onPressed:()=>action('E'),child:Text('E',style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold)))
          ]))
        ])
      )
    );
  }

  Widget _panelBody(){
    if(panel=='system')return _systemPanel();
    if(panel=='train')return _trainPanel();
    if(panel=='mode')return EmbeddedModePanel(
      mode:displayMode,clock:clock,
      onConfirm:(m,h,mi)=>setState(()=>{displayMode=m,clock=DateTime(clock.year,clock.month,clock.day,h,mi,clock.second),panel=''}),
    );
    if(panel=='bridge')return EmbeddedBridgePanel(
      host:bridgeHost,port:bridgePort,status:bridgeStatus,busy:bridgeBusy,
      onConfirm:(h,p)async{setState(()=>{bridgeHost=h;bridgePort=p});await connectBridge();if(mounted)setState(()=>panel='');},
    );
    if(panel=='keylight')return _keylightPanel();
    if(panel=='route')return _routePanel();
    if(panel=='editor')return EmbeddedEditorPanel(
      key:editorPanelKey,existing:train!=null&&train!.id.startsWith('custom-')?train:null,
      fg:fg,bg:bg,bar:bar,border:border,keyGlow:keyGlow,
      onSaved:(data)=>saveCustomFromEditor(data),
    );
    return const SizedBox.shrink();
  }

  Widget _systemPanel()=>ListView(padding:const EdgeInsets.all(10),children:[
    _systemItem('Fahrplan programmieren','Eigene Buchfahrplan-/Streckendaten im EBuLa-Display eingeben',()=>setState(()=>panel='editor')),
    _systemItem('Fahrplan auswählen','Vorhandene Fahrpläne laden',()=>setState(()=>panel='train')),
    if(train!=null&&train!.id.startsWith('custom-'))_systemItem('Aktuellen Fahrplan bearbeiten','Gespeicherten eigenen Fahrplan ändern',()=>setState(()=>panel='editor')),
    _systemItem('Anzeigepunkt','Ortung / Zeit / Manuell',()=>setState(()=>panel='mode')),
    _systemItem('TSW6 Bridge / IP','PC-Adresse und Port einstellen',()=>setState(()=>panel='bridge')),
    _systemItem('Tastenbeleuchtung','Aus / Orange / Gelb / Automatisch',()=>setState(()=>panel='keylight')),
    _systemItem('Fenster schließen','Zurück zur EBuLa-Hauptanzeige',()=>setState(()=>panel='')),
  ]);
  Widget _systemItem(String a,String b,VoidCallback f)=>Container(
    margin:const EdgeInsets.only(bottom:6),
    child:InkWell(onTap:f,child:Container(
      padding:const EdgeInsets.all(10),
      decoration:BoxDecoration(color:dark?const Color(0xff171a1c):const Color(0xfff4f4f0),border:Border.all(color:border)),
      child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(a,style:TextStyle(color:fg,fontWeight:FontWeight.bold,fontSize:12)),
          const SizedBox(height:2),Text(b,style:TextStyle(color:fg.withValues(alpha:.65),fontSize:9))
        ])),
        Text('E',style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold))
      ])
    ))
  );

  Widget _trainPanel()=>ListView(padding:const EdgeInsets.all(8),children:[
    for(final t in all)
      for(final type in t.serviceTypes)
        InkWell(onTap:()=>setState(()=>{train=t.withServiceType(type),marker=0,page=0,panel=''}),child:Container(
          margin:const EdgeInsets.only(bottom:5),padding:const EdgeInsets.all(9),
          decoration:BoxDecoration(color:train?.id==t.id&&train?.serviceType==type?bar:bg,border:Border.all(color:border)),
          child:Row(children:[
            SizedBox(width:92,child:Text(t.trainNumber,style:TextStyle(color:fg,fontWeight:FontWeight.bold,fontSize:15))),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(type+' · '+t.service,style:TextStyle(color:fg,fontWeight:FontWeight.bold,fontSize:11)),
              Text(t.vehicle+' · Vmax '+t.maxSpeed.toString()+' · '+t.validity,style:TextStyle(color:fg.withValues(alpha:.65),fontSize:9))
            ])),
            if(train?.id==t.id&&train?.serviceType==type)Icon(Icons.check,color:fg,size:18)
          ])
        )
  ]);

  Widget _keylightPanel()=>ListView(padding:const EdgeInsets.all(10),children:[
    for(final e in const[['off','Aus'],['orange','Orange'],['yellow','Gelb'],['auto','Automatisch']])
      RadioListTile<String>(value:e[0],groupValue:keyLightMode,title:Text(e[1],style:TextStyle(color:fg,fontSize:11)),
        onChanged:(v)=>setState(()=>keyLightMode=v!),contentPadding:EdgeInsets.zero)
  ]);

  Widget _routePanel()=>ListView(padding:const EdgeInsets.all(10),children:[
    Text('Fahrplan- und Streckendaten',style:TextStyle(color:fg,fontWeight:FontWeight.bold,fontSize:12)),
    const SizedBox(height:6),
    Text('Zug: '+(train?.trainNumber??'---')+'   Typ: '+(train?.serviceType??'---'),style:TextStyle(color:fg,fontSize:10)),
    Text('Strecke: '+(train?.service??'---'),style:TextStyle(color:fg,fontSize:10)),
    Text('Tfz: '+(train?.vehicle??'---')+'   Vmax: '+(train?.maxSpeed.toString()??'0')+' km/h',style:TextStyle(color:fg,fontSize:10)),
    const Divider(),
    if(train==null)Text('Kein Fahrplan geladen.',style:TextStyle(color:fg.withValues(alpha:.65),fontSize:10)),
    for(final p in train?.stops??const<StopPoint>[])
      Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Text(
        p.km.toStringAsFixed(1).padLeft(6)+'  '+(p.note??p.name).padRight(28)+'  '+(p.arrival??'--:--')+'  '+(p.departure??'--:--'),
        style:TextStyle(color:fg,fontSize:9)))
  ]);

  Future<void> saveCustomFromEditor(TimetableData data) async{
    final prefs=await SharedPreferences.getInstance();
    final current=<TimetableData>[...customTimetables.where((e)=>e.id!=data.id),data];
    await prefs.setStringList('custom_timetables',current.map((t)=>jsonEncode({
      'id':t.id,'trainNumber':t.trainNumber,'service':t.service,'serviceType':t.serviceType,'serviceTypes':t.serviceTypes,
      'validity':t.validity,'date':t.date,'vehicle':t.vehicle,'maxSpeed':t.maxSpeed,'lengthMeters':t.lengthMeters,
      'massTons':t.massTons,'brakeHundredths':t.brakeHundredths,'pzbType':t.pzbType,'notes':t.notes,
      'stops':t.stops.map((p)=>p.toJson()).toList()
    })).toList());
    applyCustomTimetableState(data,current);
  }

}

class MarkerDiamondPainter extends CustomPainter {
  final Color color;
  MarkerDiamondPainter({required this.color});
  @override void paint(Canvas c,Size s){
    final p=Paint()..color=color;
    final path=Path()..moveTo(s.width/2,0)..lineTo(s.width,s.height/2)..lineTo(s.width/2,s.height)..lineTo(0,s.height/2)..close();
    c.drawPath(path,p);
  }
  @override bool shouldRepaint(covariant MarkerDiamondPainter old)=>old.color!=color;
}

class TrackPainter extends CustomPainter {
  final bool opposite,active;
  TrackPainter({required this.opposite,required this.active});
  @override void paint(Canvas c,Size s){
    final thin=Paint()..color=const Color(0xff8e969a)..strokeWidth=1;
    final thick=Paint()..color=Colors.white..strokeWidth=2.6;
    final left=s.width*.35,right=s.width*.65;
    c.drawLine(Offset(left,0),Offset(left,s.height),thin);
    c.drawLine(Offset(right,0),Offset(right,s.height),thin);
    final x=opposite?left:right;
    c.drawLine(Offset(x,0),Offset(x,s.height),thick);
    if(active)c.drawLine(Offset(0,s.height*.52),Offset(s.width,s.height*.52),Paint()..color=Colors.white..strokeWidth=2);
  }
  @override bool shouldRepaint(covariant TrackPainter o)=>o.opposite!=opposite||o.active!=active;
}
