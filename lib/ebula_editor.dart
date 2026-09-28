// ignore_for_file: library_private_types_in_public_api, deprecated_member_use
part of 'main.dart';

class _EditorRow {
  String km='',speed='',text='',arrival='',departure='',lat='',lon='',kind='',track='',note='';
  _EditorRow();
  _EditorRow.fromStop(StopPoint p){
    km=p.km.toString();speed=p.speed?.toString()??'';text=p.name;arrival=p.arrival??'';departure=p.departure??'';
    lat=p.latitude?.toString()??'';lon=p.longitude?.toString()??'';kind=p.kind??'';track=p.track??'';note=p.note??'';
  }
}

class EmbeddedEditorPanel extends StatefulWidget {
  final TimetableData? existing;
  final Color fg,bg,bar,border,keyGlow;
  final Future<void> Function(TimetableData) onSaved;
  const EmbeddedEditorPanel({super.key,required this.existing,required this.fg,required this.bg,required this.bar,required this.border,required this.keyGlow,required this.onSaved});
  @override State<EmbeddedEditorPanel> createState()=>EmbeddedEditorPanelState();
}

class EmbeddedEditorPanelState extends State<EmbeddedEditorPanel> {
  late final TextEditingController trainNo,route,date,validity,vehicle,vmax,length,mass,brake,pzb,notes;
  late List<_EditorRow> rows;
  bool saving=false;
  @override void initState(){
    super.initState();
    final e=widget.existing;
    trainNo=TextEditingController(text:e?.trainNumber??'');
    route=TextEditingController(text:e?.service??'');
    date=TextEditingController(text:e?.date??'28.09.2026');
    validity=TextEditingController(text:e?.validity??'TSW6 / eigener Buchfahrplan');
    vehicle=TextEditingController(text:e?.vehicle??'');
    vmax=TextEditingController(text:e?.maxSpeed.toString()??'');
    length=TextEditingController(text:e?.lengthMeters.toString()??'');
    mass=TextEditingController(text:e?.massTons.toString()??'');
    brake=TextEditingController(text:e?.brakeHundredths??'');
    pzb=TextEditingController(text:e?.pzbType??'');
    notes=TextEditingController(text:e?.notes??'');
    rows=[...(e?.stops??const<StopPoint>[]).map(_EditorRow.fromStop)];
  }
  @override void dispose(){
    for(final c in [trainNo,route,date,validity,vehicle,vmax,length,mass,brake,pzb,notes])c.dispose();
    super.dispose();
  }
  void addRow()=>setState(()=>rows.insert(0,_EditorRow()));
  Future<void> save() async{
    if(saving)return;
    final stops=<StopPoint>[];
    for(final r in rows.reversed){
      final k=double.tryParse(r.km.replaceAll(',','.'));
      if(k==null||r.text.trim().isEmpty)continue;
      stops.add(StopPoint(
        name:r.text.trim(),km:k,speed:int.tryParse(r.speed.trim()),
        arrival:r.arrival.trim().isEmpty?null:r.arrival.trim(),departure:r.departure.trim().isEmpty?null:r.departure.trim(),
        note:r.note.trim().isEmpty?null:r.note.trim(),latitude:double.tryParse(r.lat.replaceAll(',','.')),
        longitude:double.tryParse(r.lon.replaceAll(',','.')),kind:r.kind.trim().isEmpty?null:r.kind.trim(),
        track:r.track.trim().isEmpty?null:r.track.trim()
      ));
    }
    if(trainNo.text.trim().isEmpty||route.text.trim().isEmpty||stops.isEmpty){
      setState(()=>saving=false);return;
    }
    setState(()=>saving=true);
    final number=trainNo.text.trim();
    final type=number.startsWith('ICE')?'ICE':number.startsWith('IC')?'IC':'Regional';
    final data=TimetableData(
      id:widget.existing?.id??'custom-'+DateTime.now().millisecondsSinceEpoch.toString(),
      trainNumber:number,service:route.text.trim(),serviceType:type,serviceTypes:<String>[type],
      validity:validity.text.trim(),date:date.text.trim(),vehicle:vehicle.text.trim(),
      maxSpeed:int.tryParse(vmax.text.trim())??0,lengthMeters:int.tryParse(length.text.trim())??0,
      massTons:int.tryParse(mass.text.trim())??0,brakeHundredths:brake.text.trim(),pzbType:pzb.text.trim(),
      notes:notes.text.trim(),stops:stops
    );
    await widget.onSaved(data);
    if(mounted)setState(()=>saving=false);
  }
  @override Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.all(7),
    children:[
      _section('Zug- und Kopfdaten'),
      Wrap(spacing:6,runSpacing:5,children:[
        _field(trainNo,'Zugnummer',95),_field(route,'Strecke / Relation',220),_field(date,'Datum',95),
        _field(validity,'Gültigkeit',145),_field(vehicle,'Tfz / Fahrzeug',140),_field(vmax,'Vmax',65),
        _field(length,'Länge m',65),_field(mass,'Masse t',65),_field(brake,'Mbr',65),_field(pzb,'PZB',75)
      ]),
      const SizedBox(height:6),
      _section('Buchfahrplan / Streckenpunkte'),
      Row(children:[
        Expanded(child:Text('Neue Zeile wird oben ergänzt. Spalten entsprechen dem EBuLa-/Buchfahrplan-Aufbau.',style:TextStyle(color:widget.fg.withValues(alpha:.65),fontSize:9))),
        ElevatedButton(onPressed:addRow,child:const Text('HINZUFÜGEN',style:TextStyle(fontSize:9)))
      ]),
      const SizedBox(height:5),
      if(rows.isEmpty)Padding(padding:const EdgeInsets.all(14),child:Text('Noch keine Streckenpunkte. Mit HINZUFÜGEN beginnen.',style:TextStyle(color:widget.fg,fontSize:10))),
      for(var i=0;i<rows.length;i++)_row(i,rows[i]),
      _section('Zusatz'),
      _field(notes,'Hinweise / Quelle',400),
      const SizedBox(height:6),
      Text('E speichert den Fahrplan dauerhaft auf dem Gerät. C schließt ohne Speichern.',style:TextStyle(color:widget.fg.withValues(alpha:.65),fontSize:9))
    ]
  );
  Widget _section(String s)=>Container(margin:const EdgeInsets.only(top:2,bottom:5),padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),color:widget.bar,child:Text(s,style:TextStyle(color:widget.fg,fontWeight:FontWeight.bold,fontSize:10)));
  Widget _field(TextEditingController c,String label,double width)=>SizedBox(width:width,child:TextField(
    controller:c,style:TextStyle(color:widget.fg,fontSize:10),decoration:InputDecoration(labelText:label,labelStyle:TextStyle(color:widget.fg.withValues(alpha:.65),fontSize:9),
    isDense:true,enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:widget.border)),focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:widget.keyGlow,width:2)))
  ));
  Widget _row(int i,_EditorRow r)=>Container(
    margin:const EdgeInsets.only(bottom:4),padding:const EdgeInsets.all(5),
    decoration:BoxDecoration(color:widget.bg,border:Border.all(color:widget.border)),
    child:Wrap(spacing:4,runSpacing:4,children:[
      _rowField(r.km,'km',65,(v)=>r.km=v),_rowField(r.speed,'V',52,(v)=>r.speed=v),
      _rowField(r.text,'Betriebsstelle / Text',175,(v)=>r.text=v),_rowField(r.arrival,'Ank',65,(v)=>r.arrival=v),
      _rowField(r.departure,'Abf',65,(v)=>r.departure=v),_rowField(r.kind,'Art',60,(v)=>r.kind=v),
      _rowField(r.track,'Gl',45,(v)=>r.track=v),_rowField(r.lat,'Lat',85,(v)=>r.lat=v),_rowField(r.lon,'Lon',85,(v)=>r.lon=v),
      _rowField(r.note,'Hinweis',135,(v)=>r.note=v),
      IconButton(onPressed:()=>setState(()=>rows.removeAt(i)),icon:Icon(Icons.delete_outline,color:widget.keyGlow,size:18))
    ])
  );
  Widget _rowField(String value,String label,double width,ValueChanged<String> change){
    return SizedBox(width:width,child:TextFormField(initialValue:value,onChanged:change,style:TextStyle(color:widget.fg,fontSize:9),
      decoration:InputDecoration(labelText:label,labelStyle:TextStyle(color:widget.fg.withValues(alpha:.55),fontSize:8),isDense:true,border:OutlineInputBorder(borderSide:BorderSide(color:widget.border)))));
  }
}

class EmbeddedModePanel extends StatefulWidget {
  final String mode;final DateTime clock;final Color fg,bg,border;final void Function(String,int,int) onConfirm;
  const EmbeddedModePanel({super.key,required this.mode,required this.clock,required this.fg,required this.bg,required this.border,required this.onConfirm});
  @override State<EmbeddedModePanel> createState()=>EmbeddedModePanelState();
}
class EmbeddedModePanelState extends State<EmbeddedModePanel>{
  late String mode;late int h,m;
  @override void initState(){super.initState();mode=widget.mode;h=widget.clock.hour;m=widget.clock.minute;}
  void confirm()=>widget.onConfirm(mode,h,m);
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(10),children:[
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      IconButton(onPressed:()=>setState(()=>h=(h+23)%24),icon:Icon(Icons.remove,color:widget.fg)),
      Text(h.toString().padLeft(2,'0'),style:TextStyle(color:widget.fg,fontSize:24)),
      IconButton(onPressed:()=>setState(()=>h=(h+1)%24),icon:Icon(Icons.add,color:widget.fg)),
      const Text(':',style:TextStyle(color:Colors.white,fontSize:24)),
      IconButton(onPressed:()=>setState(()=>m=(m+59)%60),icon:const Icon(Icons.remove,color:Colors.white)),
      Text(m.toString().padLeft(2,'0'),style:const TextStyle(color:Colors.white,fontSize:24)),
      IconButton(onPressed:()=>setState(()=>m=(m+1)%60),icon:const Icon(Icons.add,color:Colors.white))
    ]),
    Divider(color:widget.border),
    _tile('manual','Manuell','Zeiger mit ▲ / ▼ bewegen'),
    _tile('time','Per Zeit','Zeiger folgt der Fahrplanzeit'),
    _tile('location','Per Ortung','Zeiger folgt TSW6 über die Bridge'),
    const SizedBox(height:8),
    Text('E übernimmt die Auswahl. C schließt.',style:TextStyle(color:widget.fg.withValues(alpha:.62),fontSize:9))
  ]);
  Widget _tile(String v,String a,String b)=>RadioListTile<String>(
    value:v,groupValue:mode,onChanged:(x)=>setState(()=>mode=x!),
    title:Text(a,style:TextStyle(color:widget.fg,fontSize:11)),subtitle:Text(b,style:TextStyle(color:widget.fg.withValues(alpha:.62),fontSize:9)),
    contentPadding:EdgeInsets.zero);
}

class EmbeddedBridgePanel extends StatefulWidget {
  final String host;final int port;final String status;final bool busy;final double? liveKm,routeDistanceM;final String routeId;
  final Color fg,bg,border,keyGlow;
  final Future<void> Function(String,int) onConfirm;final Future<void> Function() onRecordStart,onRecordStop,onDiagnostics;
  const EmbeddedBridgePanel({super.key,required this.host,required this.port,required this.status,required this.busy,required this.liveKm,required this.routeId,required this.routeDistanceM,required this.fg,required this.bg,required this.border,required this.keyGlow,required this.onConfirm,required this.onRecordStart,required this.onRecordStop,required this.onDiagnostics});
  @override State<EmbeddedBridgePanel> createState()=>EmbeddedBridgePanelState();
}
class EmbeddedBridgePanelState extends State<EmbeddedBridgePanel>{
  late final TextEditingController host,port;bool running=false,recording=false;
  @override void initState(){super.initState();host=TextEditingController(text:widget.host);port=TextEditingController(text:widget.port.toString());}
  @override void dispose(){host.dispose();port.dispose();super.dispose();}
  Future<void> confirm()async{
    if(running)return;final p=int.tryParse(port.text.trim())??8080;
    setState(()=>running=true);await widget.onConfirm(host.text.trim(),p);if(mounted)setState(()=>running=false);
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(12),children:[
    Text('Tablet → PC → Pure EBuLa Bridge',style:TextStyle(color:widget.fg.withValues(alpha:.75),fontSize:10)),
    const SizedBox(height:8),
    _field(host,'PC-IP / Hostname'),const SizedBox(height:7),_field(port,'Port',num:true),
    const SizedBox(height:10),
    Text('Aktueller Status: '+widget.status,style:TextStyle(color:widget.status.contains('Verbunden')?Colors.green.shade700:widget.fg,fontSize:10)),
    const SizedBox(height:8),
    Row(children:[
      Expanded(child:ElevatedButton(onPressed:running?null:confirm,child:Text(running?'VERBINDE …':'VERBINDEN / E'))),
      const SizedBox(width:6),
      Expanded(child:ElevatedButton(onPressed:running?null:()async{
        setState(()=>recording=true); await widget.onRecordStart();
      },child:Text(recording?'AUFNAHME LÄUFT':'STRECKE AUFNEHMEN'))),
    ]),
    if(recording)Padding(padding:const EdgeInsets.only(top:6),child:ElevatedButton(onPressed:()async{
      await widget.onRecordStop(); if(mounted)setState(()=>recording=false);
    },child:const Text('AUFNAHME STOPPEN'))),
    const SizedBox(height:8),
    Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:widget.bg,border:Border.all(color:widget.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Live-Streckenzuordnung',style:TextStyle(color:widget.fg,fontWeight:FontWeight.bold,fontSize:10)),
      const SizedBox(height:3),
      Text(widget.routeId.isEmpty?'Keine Route-Datei zugeordnet':'Route: '+widget.routeId,style:TextStyle(color:widget.fg,fontSize:9)),
      Text(widget.liveKm==null?'km: —':'km: '+widget.liveKm!.toStringAsFixed(3).replaceAll('.',','),style:TextStyle(color:widget.fg,fontSize:9)),
      if(widget.routeDistanceM!=null)Text('Abstand zur Geometrie: '+widget.routeDistanceM!.toStringAsFixed(0)+' m',style:TextStyle(color:widget.fg.withValues(alpha:.65),fontSize:8)),
    ])),
    const SizedBox(height:7),
    OutlinedButton(onPressed:widget.onDiagnostics,child:Text('TSW-DIAGNOSE AKTUALISIEREN',style:TextStyle(color:widget.fg,fontSize:9))),
    const SizedBox(height:7),
    Text('Streckendaten werden getrennt vom Fahrplan als eigene Geometrie gespeichert. Die Aufzeichnung nutzt nur die TSW6-API-Daten.',style:TextStyle(color:widget.fg.withValues(alpha:.6),fontSize:8))
  ]);
  Widget _field(TextEditingController c,String label,{bool num=false})=>TextField(
    controller:c,keyboardType:num?TextInputType.number:TextInputType.text,style:TextStyle(color:widget.fg,fontSize:11),
    decoration:InputDecoration(labelText:label,labelStyle:TextStyle(color:widget.fg.withValues(alpha:.7),fontSize:10),
      enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:widget.border)),focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:widget.keyGlow,width:2)))
  );
}
