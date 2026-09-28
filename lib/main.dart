// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const StopPoint({required this.name, required this.km, this.speed, this.arrival, this.departure, this.note});
  factory StopPoint.fromJson(Map<String,dynamic> j) => StopPoint(
    name: j['name'] as String, km: (j['km'] as num).toDouble(),
    speed: (j['speed'] as num?)?.toInt(), arrival: j['arrival'] as String?,
    departure: j['departure'] as String?, note: j['note'] as String?,
  );
}

class TimetableData {
  final String id, trainNumber, service, serviceType, validity, date, vehicle;
  final int maxSpeed, lengthMeters, massTons;
  final List<StopPoint> stops;
  const TimetableData({
    required this.id, required this.trainNumber, required this.service, required this.serviceType,
    required this.validity, required this.date, required this.vehicle,
    required this.maxSpeed, required this.lengthMeters, required this.massTons,
    required this.stops,
  });
  factory TimetableData.fromJson(Map<String,dynamic> j) => TimetableData(
    id: j['id'] as String, trainNumber: j['trainNumber'] as String,
    service: j['service'] as String,
    serviceType: (j['serviceType'] as String?) ?? ((j['trainNumber'] as String).startsWith('ICE') ? 'ICE' : ((j['trainNumber'] as String).startsWith('IC') ? 'IC' : 'S-Bahn')),
    validity: j['validity'] as String,
    date: j['date'] as String, vehicle: j['vehicle'] as String,
    maxSpeed: (j['maxSpeed'] as num).toInt(),
    lengthMeters: (j['lengthMeters'] as num).toInt(),
    massTons: (j['massTons'] as num).toInt(),
    stops: (j['stops'] as List).map((e) => StopPoint.fromJson(e as Map<String,dynamic>)).toList(),
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
  int marker = 0, page = 0;
  bool paused=false, night=false, dark=false, fullscreen=false, opposite=false, markerPause=false, keyLights=false;
  String keyLightMode='orange';
  String overlay='';
  String displayMode='time';
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
    clockTimer = Timer.periodic(const Duration(seconds:1), (_) {
      if (!paused && mounted) setState(() { clock = clock.add(const Duration(seconds:1)); if(displayMode=='time' && train!=null && train!.stops.isNotEmpty) { final next=train!.stops.indexWhere((p){ final t=p.arrival??p.departure; return t!=null && t==clock.hour.toString().padLeft(2,'0')+':'+clock.minute.toString().padLeft(2,'0'); }); if(next>=0) marker=next; } });
    });
  }
  Future<void> load() async {
    final list=<TimetableData>[];
    for(final f in files) {
      final raw=await rootBundle.loadString(f);
      list.add(TimetableData.fromJson(jsonDecode(raw) as Map<String,dynamic>));
    }
    if(!mounted) return;
    setState(() { all=list; train=list.first; resetPosition(); });
  }
  @override void dispose(){clockTimer?.cancel();super.dispose();}

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
    if(a=='G'){setState(()=>overlay=''); return;}
    if(a=='Zug'){showTrain();}
    else if(a=='FSD'){setState(()=>overlay=overlay=='FSD'?'':'FSD');}
    else if(a=='GW'){setState(()=>opposite=!opposite);}
    else if(a=='Zeit'){showTime();}
    else if(a=='S'){setState(()=>paused=!paused);}
    else if(a=='I'){showKeyLightSettings();}
    else if(a=='St'){showBridge();}
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
    else if(a=='E'){setState(()=>markerPause=!markerPause);}
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
          Expanded(child:ListView.builder(
            padding:const EdgeInsets.all(8),itemCount:all.length,itemBuilder:(_,i){
              final t=all[i], selected=train?.id==t.id;
              return InkWell(
                onTap:(){setState(() { train=t; resetPosition(); overlay=''; });Navigator.pop(context);},
                child:Container(
                  margin:const EdgeInsets.only(bottom:6),
                  padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),
                  decoration:BoxDecoration(
                    color:selected?const Color(0xff53616a):const Color(0xff24282a),
                    border:Border.all(color:selected?Colors.white:const Color(0xff62696d)),
                  ),
                  child:Row(children:[
                    SizedBox(width:92,child:Text(t.trainNumber,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16))),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(t.serviceType+'  ·  '+t.service,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
                      Text(t.vehicle+'   Vmax '+t.maxSpeed.toString()+' km/h   '+t.validity,style:const TextStyle(color:Colors.white70,fontSize:10)),
                    ])),
                    if(selected) const Icon(Icons.check,color:Colors.white),
                  ]),
                ),
              );
            },
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
      final req=await client.get(host, bridgePort, '/');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res=await req.close().timeout(const Duration(seconds:4));
      await res.drain();
      client.close(force:true);
      if(!mounted) return;
      setState(() { bridgeBusy=false; bridgeStatus='Verbunden'; });
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
    const labels=['aus','S','I','St','V>0','V=0','✸','◑','UD'];
    return Container(height:49,color:const Color(0xff101010),padding:const EdgeInsets.fromLTRB(10,7,10,4),child:Row(
      children:labels.map((l)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:physicalKey(l,()=>action(
        l=='S'?'S':l=='I'?'I':l=='St'?'St':l=='✸'?'Tag/Nacht':l=='◑'?'Hell/Dunkel':l=='UD'?'UD':''
      ))))).toList(),
    ));
  }

  Widget sideKeys()=>SizedBox(width:58,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    sideKey('▲','▲'),const SizedBox(height:6),sideKey('◀','⯇'),const SizedBox(height:6),sideKey('▶','⯈'),const SizedBox(height:6),sideKey('▼','▼'),
  ]));
  Widget sideKey(String label,String actionName)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(vertical:1),child:InkWell(onTap:()=>action(actionName),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xff080808),border:Border.all(color:keyGlow,width:keyLightMode=='off'?1:2),borderRadius:BorderRadius.circular(3)),child:Text(label,style:TextStyle(color:keyGlow,fontSize:22,fontWeight:FontWeight.bold))))));
  Widget bottomKeys(){
    const labels=['1','2','3','4','5','6','7','8','9','0'];
    const actions=['Zug','FSD','','▲','▼','GW','Zeit','','','G'];
    return Container(height:51,color:const Color(0xff0d0d0d),padding:const EdgeInsets.fromLTRB(9,3,9,7),child:Row(
      children:List.generate(10,(i)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:4),child:physicalKey(labels[i],()=>action(actions[i]))))),
    ));
  }

  Widget physicalKey(String text,VoidCallback onTap)=>SizedBox(height:34,child:InkWell(onTap:onTap,child:Container(
    alignment:Alignment.center,
    decoration:BoxDecoration(color:const Color(0xff080808),border:Border.all(color:keyGlow,width:keyLightMode=='off'?1.0:2.0),borderRadius:BorderRadius.circular(3),boxShadow:keyLightMode=='off'?const []:[BoxShadow(color:Color(0x66f0a13a),blurRadius:5,spreadRadius:.3)]),
    child:Text(text,style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold,fontSize:12,shadows:keyLightMode=='off'?const []:[Shadow(color:keyGlow,blurRadius:4)])),
  )));

  Widget screen(){
    final list=train?.stops.skip(page).take(8).toList() ?? const <StopPoint>[];
    return Stack(
      children:[
        Container(
          decoration:BoxDecoration(color:bg,border:Border.all(color:const Color(0xff9aa1a5),width:2)),
          child:Column(children:[header(),routeBar(),Expanded(child:table(list)),status(),softkeys(),]),
        ),
        if(overlay=='FSD') fsdOverlay(),
      ],
    );
  }

  Widget header()=>SizedBox(height:43,child:Row(children:[
    headerCell(train?.trainNumber??'---',18,17),
    headerCell('EBuLa-Karte gültig!',38,12),
    headerCell(train?.date??'--.--.----',18,12),
    headerCell(clockText(),26,17,red:paused),
  ]));

  Widget headerCell(String text,int flex,double size,{bool red=false})=>Expanded(flex:flex,child:Container(
    alignment:Alignment.center,decoration:BoxDecoration(border:Border.all(color:border)),
    child:FittedBox(child:Text(text,style:TextStyle(color:red?const Color(0xffd94a4a):fg,fontWeight:FontWeight.bold,fontSize:size))),
  ));

  Widget routeBar()=>Container(height:27,color:bar,padding:const EdgeInsets.symmetric(horizontal:6),child:Row(children:[
    Text(opposite?'/l':'/r',style:TextStyle(color:fg,fontWeight:FontWeight.bold)),
    const SizedBox(width:10),
    Expanded(child:Text((train?.serviceType??'')+'  '+(train?.service??''),overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:10))),
    Text('Nächster Halt: '+(point?.name??'--'),style:TextStyle(color:fg,fontSize:9,fontWeight:FontWeight.bold)),
  ]));

  Widget table(List<StopPoint> rows)=>Column(children:[
    SizedBox(height:24,child:Row(children:[
      cell('V',9,true,true),cell('km',10,true,true),cell('Fahrweg',18,true,true),cell('Betriebsstelle / Text',35,false,true),cell('Ank',12,true,true),cell('Abf',12,true,true),
    ])),
    Expanded(child:ListView.builder(itemCount:rows.length,itemBuilder:(_,i){
      final p=rows[i], active=page+i==marker;
      return SizedBox(height:48,child:Row(children:[
        cell(p.speed?.toString()??'',9,true,active),cell(p.km.toStringAsFixed(1),10,true,active),
        Expanded(flex:18,child:CustomPaint(painter:TrackPainter(opposite:opposite,active:active))),
        Expanded(flex:35,child:Container(
          color:active?(dark?const Color(0xff30383c):const Color(0xffd5d9db)):null,
          alignment:Alignment.centerLeft,padding:const EdgeInsets.symmetric(horizontal:5),
          child:Text(p.note??p.name,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:10,fontWeight:active?FontWeight.bold:FontWeight.normal)),
        )),
        cell(p.arrival??'',12,true,p.arrival!=null),cell(p.departure??'',12,true,p.departure!=null),
      ]));
    })),
  ]);

  Widget cell(String text,int flex,bool center,bool bold)=>Expanded(flex:flex,child:Container(
    alignment:center?Alignment.center:Alignment.centerLeft,padding:const EdgeInsets.symmetric(horizontal:3),
    decoration:BoxDecoration(border:Border(bottom:BorderSide(color:border,width:.7))),
    child:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:10,fontWeight:bold?FontWeight.bold:FontWeight.normal)),
  ));

  Widget status()=>Container(height:25,color:bar,padding:const EdgeInsets.symmetric(horizontal:5),child:Row(children:[
    Text((displayMode=='location'?'ORT':'')+' '+(opposite?'RW/l':'RW/r',style:TextStyle(color:fg,fontSize:9,fontWeight:FontWeight.bold)),
    const SizedBox(width:12),Text('GSM-R',style:TextStyle(color:fg,fontSize:9)),
    const Spacer(),Text('V='+(point?.speed?.toString()??train?.maxSpeed.toString()??'0')+' km/h',style:TextStyle(color:fg,fontSize:9,fontWeight:FontWeight.bold)),
    const SizedBox(width:12),Text('km '+(point?.km.toStringAsFixed(1)??'--'),style:TextStyle(color:fg,fontSize:9)),
    const SizedBox(width:12),Text(markerPause?'PAUSE':(marker+1).toString()+'/'+(train?.stops.length??0).toString(),style:TextStyle(color:markerPause?const Color(0xffd94a4a):fg,fontSize:9,fontWeight:FontWeight.bold)),
  ]));

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

  Widget softkeys(){
    const labels=[['Zug','Zug'],['FSD','FSD'],['',''],['▲','▲'],['▼','▼'],['GW','GW'],['Zeit','Zeit'],['',''],['',''],['G','G']];
    return SizedBox(height:39,child:Row(children:List.generate(10,(i){
      final enabled=labels[i][0].isNotEmpty;
      return Expanded(child:Container(
        margin:const EdgeInsets.symmetric(horizontal:.5),
        decoration:BoxDecoration(color:enabled?const Color(0xff59656a):const Color(0xff444b4f),border:Border.all(color:const Color(0xff9ba3a7))),
        child:InkWell(onTap:enabled?()=>action(labels[i][0]):null,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text((i+1).toString(),style:const TextStyle(color:Colors.white54,fontSize:8)),
          Text(labels[i][1],style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold)),
        ])),
      ));
    })));
  }
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
