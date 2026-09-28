import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const PureEBuLaApp());

class PureEBuLaApp extends StatelessWidget {
  const PureEBuLaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Pure EBuLa',
    theme: ThemeData(useMaterial3: false, fontFamily: 'monospace'),
    home: const SplashScreen(),
  );
}



class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EBuLaScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: .28, end: 1.0).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
          ),
          child: const Text(
            'EBuLa',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 58,
              fontWeight: FontWeight.bold,
              letterSpacing: 5,
            ),
          ),
        ),
      ),
    );
  }
}

class StopPoint {
  final String name;
  final double km;
  final int? speed;
  final String? arrival;
  final String? departure;
  final String? note;
  const StopPoint({required this.name, required this.km, this.speed, this.arrival, this.departure, this.note});
  factory StopPoint.fromJson(Map<String,dynamic> j) => StopPoint(
    name: j['name'] as String,
    km: (j['km'] as num).toDouble(),
    speed: (j['speed'] as num?)?.toInt(),
    arrival: j['arrival'] as String?,
    departure: j['departure'] as String?,
    note: j['note'] as String?,
  );
}

class EBuLaScreen extends StatefulWidget {
  const EBuLaScreen({super.key});
  @override State<EBuLaScreen> createState() => _EBuLaScreenState();
}

class _EBuLaScreenState extends State<EBuLaScreen> {
  List<StopPoint> points = [];
  DateTime clock = DateTime(2020,9,28,8,4,37);
  Timer? timer;
  bool paused=false, night=false, dark=true, full=false, opposite=false, markerPause=false;
  int marker=0, page=0, speedRepeat=160;
  String mode='ZEIT', overlay='';

  Color get bg => night ? const Color(0xff101820) : (dark ? const Color(0xff151515) : const Color(0xffd8d8d8));
  Color get fg => night ? const Color(0xffc7dcff) : (dark ? const Color(0xffeeeeee) : const Color(0xff111111));
  Color get panel => night ? const Color(0xff1b2633) : (dark ? const Color(0xff242424) : const Color(0xffeeeeee));

  @override void initState() {
    super.initState();
    _load();
    timer=Timer.periodic(const Duration(seconds:1), (_) {
      if (!paused && mounted) setState(() => clock=clock.add(const Duration(seconds:1)));
    });
  }
  Future<void> _load() async {
    final raw=await rootBundle.loadString('assets/timetables/ice15.json');
    final j=jsonDecode(raw) as Map<String,dynamic>;
    setState(() => points=(j['stops'] as List).map((e)=>StopPoint.fromJson(e)).toList());
  }
  @override void dispose(){timer?.cancel();super.dispose();}

  String timeText() => clock.hour.toString().padLeft(2,'0')+':'+clock.minute.toString().padLeft(2,'0')+':'+clock.second.toString().padLeft(2,'0');
  String nextStop() => points.isEmpty ? '--' : points[marker].name;

  void move(int d) {
    if(points.isEmpty)return;
    setState((){
      marker=(marker+d).clamp(0,points.length-1).toInt();
      speedRepeat=points[marker].speed ?? speedRepeat;
      page=marker;
    });
  }
  void adjust(int s)=>setState(()=>clock=clock.add(Duration(seconds:s)));

  void key(String k) {
    if(k=='1') showTrain();
    else if(k=='2') setState(()=>overlay=overlay=='FSD'?'':'FSD');
    else if(k=='6') setState(()=>opposite=!opposite);
    else if(k=='7') showTime();
    else if(k=='S') setState(()=>paused=!paused);
    else if(k=='-5s') adjust(-5);
    else if(k=='+5s') adjust(5);
    else if(k=='✸') setState(()=>night=!night);
    else if(k=='◑') setState(()=>dark=!dark);
    else if(k=='UD') toggleFull();
    else if(k=='▲') move(-1);
    else if(k=='▼') move(1);
    else if(k=='⯈') setState(()=>page=(page+6).clamp(0,points.length>1?points.length-1:0).toInt());
    else if(k=='⯇') setState(()=>page=(page-6).clamp(0,points.length>1?points.length-1:0).toInt());
    else if(k=='E') setState(()=>markerPause=!markerPause);
  }

  void toggleFull(){
    setState(()=>full=!full);
    SystemChrome.setEnabledSystemUIMode(full?SystemUiMode.immersiveSticky:SystemUiMode.edgeToEdge);
  }

  void showTrain()=>showDialog(context:context,builder:(_)=>AlertDialog(
    backgroundColor:const Color(0xff202020),
    title:const Text('Zug / Fahrplan',style:TextStyle(color:Colors.white)),
    content:const Text('ICE 15\nKöln Hbf – Frankfurt(Main) Hbf',style:TextStyle(color:Colors.white,fontSize:18)),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('C'))],
  ));

  void showTime(){
    int h=clock.hour,m=clock.minute;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(c,local)=>AlertDialog(
      backgroundColor:const Color(0xff202020),
      title:const Text('EBuLa-Zeit',style:TextStyle(color:Colors.white)),
      content:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(onPressed:()=>local(()=>h=(h+23)%24),icon:const Icon(Icons.remove,color:Colors.white)),
        Text(h.toString().padLeft(2,'0'),style:const TextStyle(color:Colors.white,fontSize:28)),
        IconButton(onPressed:()=>local(()=>h=(h+1)%24),icon:const Icon(Icons.add,color:Colors.white)),
        const Text(':',style:TextStyle(color:Colors.white,fontSize:28)),
        IconButton(onPressed:()=>local(()=>m=(m+59)%60),icon:const Icon(Icons.remove,color:Colors.white)),
        Text(m.toString().padLeft(2,'0'),style:const TextStyle(color:Colors.white,fontSize:28)),
        IconButton(onPressed:()=>local(()=>m=(m+1)%60),icon:const Icon(Icons.add,color:Colors.white)),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('C')),
        TextButton(onPressed:(){setState(()=>clock=DateTime(clock.year,clock.month,clock.day,h,m,clock.second));Navigator.pop(context);},child:const Text('E')),
      ],
    )));
  }

  @override Widget build(BuildContext context){
    final rows=points.skip(page).take(10).toList();
    return Scaffold(
      backgroundColor:bg,
      body:SafeArea(child:Column(children:[
        topKeys(),
        Expanded(child:Stack(children:[display(rows),if(overlay.isNotEmpty) fsdOverlay()])),
        softKeys(),
      ])),
    );
  }

  Widget topKeys()=>Container(
    color:const Color(0xff303030),padding:const EdgeInsets.all(5),
    child:Row(children:['aus',paused?'S▶':'S','I','St','-5s','+5s','✸','◑',full?'UD×':'UD'].map((x)=>keyButton(x)).toList()),
  );

  Widget keyButton(String t)=>Expanded(child:Padding(
    padding:const EdgeInsets.symmetric(horizontal:2),
    child:SizedBox(height:36,child:ElevatedButton(
      onPressed:()=>key(t=='S▶'?'S':t),
      style:ElevatedButton.styleFrom(backgroundColor:const Color(0xff424242),foregroundColor:Colors.white,padding:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(2))),
      child:FittedBox(child:Text(t,style:const TextStyle(fontWeight:FontWeight.bold))),
    )),
  ));

  Widget softKeys(){
    final data=[['1','Zug'],['2','FSD'],['3',''],['4','▲'],['5','▼'],['6','GW'],['7','Zeit'],['8',''],['9','⯇'],['0','⯈']];
    return Container(color:const Color(0xff292929),padding:const EdgeInsets.all(5),
      child:Row(children:data.map((x)=>Expanded(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:2),
        child:SizedBox(height:48,child:ElevatedButton(
          onPressed:()=>key(x[0]),
          style:ElevatedButton.styleFrom(backgroundColor:const Color(0xff3a3a3a),foregroundColor:Colors.white,padding:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(2))),
          child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(x[0],style:const TextStyle(fontWeight:FontWeight.bold)),if(x[1].isNotEmpty)Text(x[1],style:const TextStyle(fontSize:10))]),
        )),
      ))).toList()));
  }

  Widget display(List<StopPoint> rows)=>Container(
    margin:const EdgeInsets.all(6),
    decoration:BoxDecoration(color:panel,border:Border.all(color:const Color(0xff777777))),
    child:Column(children:[
      Container(height:54,color:const Color(0xff222222),padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[
        Text('ICE 15',style:TextStyle(color:fg,fontSize:21,fontWeight:FontWeight.bold)),
        const Spacer(),
        Text('28.09.2020',style:TextStyle(color:fg,fontSize:16)),
        const SizedBox(width:18),
        Text(timeText(),style:TextStyle(color:paused?Colors.redAccent:fg,fontSize:20,fontWeight:FontWeight.bold)),
      ])),
      Container(height:27,color:const Color(0xff343434),padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[
        Text(opposite?'/l':'/r',style:TextStyle(color:fg,fontWeight:FontWeight.bold)),
        const SizedBox(width:16),
        Expanded(child:Text('Nächster Halt: '+nextStop(),style:TextStyle(color:fg))),
        Text(mode+(markerPause?' PAUSE':''),style:TextStyle(color:fg,fontWeight:FontWeight.bold)),
      ])),
      Expanded(child:table(rows)),
      Container(height:34,color:const Color(0xff303030),padding:const EdgeInsets.symmetric(horizontal:8),child:Row(children:[
        Text('V='+speedRepeat.toString()+' km/h',style:TextStyle(color:fg,fontWeight:FontWeight.bold)),
        const SizedBox(width:18),
        Text(points.isEmpty?'km --':'km '+points[marker].km.toStringAsFixed(1),style:TextStyle(color:fg)),
        const Spacer(),
        Text((opposite?'Gegengleis':'Regelgleis')+'   '+(marker+1).toString()+'/'+points.length.toString(),style:TextStyle(color:fg)),
      ])),
    ]),
  );

  Widget table(List<StopPoint> rows)=>Column(children:[
    Container(height:30,color:const Color(0xff444444),child:Row(children:[
      cell('V',9,true),cell('km',10,true),cell('Grafik',15,true),cell('Betriebsstelle / Text',31,false),cell('Ank',10,true),cell('Abf',10,true),
    ])),
    Expanded(child:ListView.builder(itemCount:rows.length,itemBuilder:(_,i){
      final p=rows[i], active=page+i==marker;
      return Container(height:43,color:active?const Color(0xff565656):Colors.transparent,
        child:Row(children:[
          cell(p.speed?.toString()??'',9,true),cell(p.km.toStringAsFixed(1),10,true),
          Expanded(flex:15,child:CustomPaint(painter:TrackPainter(opposite:opposite,active:active))),
          Expanded(flex:31,child:Padding(padding:const EdgeInsets.symmetric(horizontal:6),child:Text(p.note??p.name,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:14,fontWeight:p.arrival!=null?FontWeight.bold:FontWeight.normal)))),
          cell(p.arrival??'',10,true),cell(p.departure??'',10,true),
        ]),
      );
    })),
  ]);

  Widget cell(String s,int flex,bool center)=>Expanded(flex:flex,child:Container(
    alignment:center?Alignment.center:Alignment.centerLeft,padding:const EdgeInsets.symmetric(horizontal:3),
    child:Text(s,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:fg,fontSize:12,fontWeight:FontWeight.bold)),
  ));

  Widget fsdOverlay()=>Positioned.fill(child:Container(color:const Color(0xee101010),padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Text('FSD – Fahrplandaten',style:TextStyle(color:fg,fontSize:24,fontWeight:FontWeight.bold)),const Spacer(),IconButton(onPressed:()=>setState(()=>overlay=''),icon:Icon(Icons.close,color:fg))]),
    Text('Zug: ICE 15',style:TextStyle(color:fg,fontSize:18)),
    Text('Strecke: Köln Hbf – Frankfurt(Main) Hbf',style:TextStyle(color:fg,fontSize:18)),
    Text('Fahrzeug: ICE 3    Vmax: 300 km/h',style:TextStyle(color:fg,fontSize:18)),
    Text('Masse: 409 t    Länge: 201 m',style:TextStyle(color:fg,fontSize:18)),
    const SizedBox(height:14),
    Text('Halte / Betriebsstellen',style:TextStyle(color:fg,fontSize:18,fontWeight:FontWeight.bold)),
    Expanded(child:ListView(children:points.map((p)=>Text(p.km.toStringAsFixed(1).padLeft(6)+'   '+p.name.padRight(22)+'   '+(p.arrival??'--')+' / '+(p.departure??'--'),style:TextStyle(color:fg,fontSize:14,height:1.5))).toList())),
  ])));

}

class TrackPainter extends CustomPainter {
  final bool opposite,active;
  TrackPainter({required this.opposite,required this.active});
  @override void paint(Canvas c,Size s){
    final p=Paint()..color=Colors.white..strokeWidth=opposite?3:2;
    final x=opposite?s.width*.68:s.width*.32;
    final y=opposite?s.width*.32:s.width*.68;
    c.drawLine(Offset(x,0),Offset(x,s.height),p);
    c.drawLine(Offset(y,0),Offset(y,s.height),Paint()..color=Colors.white..strokeWidth=1);
    if(active)c.drawLine(Offset(0,s.height/2),Offset(s.width,s.height/2),Paint()..color=Colors.white..strokeWidth=3);
  }
  @override bool shouldRepaint(covariant TrackPainter o)=>o.opposite!=opposite||o.active!=active;
}
