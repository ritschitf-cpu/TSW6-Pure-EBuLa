// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
part of 'main.dart';

class _EditorRow {
  String km='', speed='', text='', arrival='', departure='', lat='', lon='', kind='', track='', note='';
  _EditorRow();
  _EditorRow.fromStop(StopPoint p){
    km=p.km.toString();
    speed=p.speed?.toString()??'';
    text=p.name;
    arrival=p.arrival??'';
    departure=p.departure??'';
    lat=p.latitude?.toString()??'';
    lon=p.longitude?.toString()??'';
    kind=p.kind??'';
    track=p.track??'';
    note=p.note??'';
  }
}

extension EBuLaEditor on _EBuLaScreenState {
  Future<void> showEditor({TimetableData? existing}) async {
    final trainNo=TextEditingController(text:existing?.trainNumber??'');
    final route=TextEditingController(text:existing?.service??'');
    final date=TextEditingController(text:existing?.date??'28.09.2026');
    final validity=TextEditingController(text:existing?.validity??'eigener Fahrplan');
    final vehicle=TextEditingController(text:existing?.vehicle??'');
    final vmax=TextEditingController(text:existing?.maxSpeed.toString()??'');
    final length=TextEditingController(text:existing?.lengthMeters.toString()??'');
    final mass=TextEditingController(text:existing?.massTons.toString()??'');
    final brake=TextEditingController(text:existing?.brakeHundredths??'');
    final pzb=TextEditingController(text:existing?.pzbType??'');
    final notes=TextEditingController(text:existing?.notes??'');
    final rows=< _EditorRow >[
      ...((existing?.stops??const <StopPoint>[]).map((p)=>_EditorRow.fromStop(p)))
    ];
    bool saving=false;

    await showDialog<void>(
      context:context,
      barrierDismissible:false,
      barrierColor:Colors.black54,
      builder:(dialogContext)=>StatefulBuilder(builder:(context,setLocal){
        Widget field(TextEditingController c,String label,{double width=130}){
          return SizedBox(width:width,child:TextField(
            controller:c,
            style:TextStyle(color:fg,fontSize:11),
            decoration:InputDecoration(
              labelText:label,labelStyle:TextStyle(color:fg.withValues(alpha:.65),fontSize:10),
              enabledBorder:OutlineInputBorder(borderSide:BorderSide(color:border)),
              focusedBorder:OutlineInputBorder(borderSide:BorderSide(color:keyGlow,width:2)),
              isDense:true,
            ),
          ));
        }
        Widget rowField(String value,void Function(String) onChanged,String label,{double width=110}){
          final c=TextEditingController(text:value);
          return SizedBox(width:width,child:TextField(
            controller:c,
            onChanged:onChanged,
            style:TextStyle(color:fg,fontSize:10),
            decoration:InputDecoration(labelText:label,labelStyle:TextStyle(color:fg.withValues(alpha:.65),fontSize:9),isDense:true,border:OutlineInputBorder(borderSide:BorderSide(color:border))),
          ));
        }

        return Dialog(
          backgroundColor:bg,
          insetPadding:const EdgeInsets.symmetric(horizontal:34,vertical:24),
          shape:const RoundedRectangleBorder(borderRadius:BorderRadius.zero),
          child:SizedBox(
            width:980,height:620,
            child:Column(children:[
              Container(height:38,color:bar,padding:const EdgeInsets.symmetric(horizontal:10),child:Row(children:[
                Text('Streckendaten / eigener Buchfahrplan',style:TextStyle(color:fg,fontWeight:FontWeight.bold,fontSize:14)),
                const Spacer(),
                Text('E = übernehmen   C = zurück',style:TextStyle(color:fg,fontSize:9)),
              ])),
              Padding(padding:const EdgeInsets.all(8),child:Wrap(spacing:7,runSpacing:6,children:[
                field(trainNo,'Zugnummer',width:100),
                field(route,'Strecke / Relation',width:250),
                field(date,'Datum',width:110),
                field(validity,'Gültigkeit',width:150),
                field(vehicle,'Tfz / Fahrzeug',width:150),
                field(vmax,'Vmax',width:75),
                field(length,'Länge m',width:75),
                field(mass,'Masse t',width:75),
                field(brake,'Mbr',width:75),
                field(pzb,'PZB',width:90),
              ])),
              Container(height:28,color:bar,child:Row(children:[
                const SizedBox(width:8),
                Text('Jede neue Zeile wird oben ergänzt. Reihenfolge = Fahrtrichtung.',style:TextStyle(color:fg,fontSize:9)),
                const Spacer(),
                Text(rows.length.toString()+' Streckenpunkte',style:TextStyle(color:fg,fontSize:9)),
                const SizedBox(width:8),
              ])),
              Expanded(child:ListView.builder(
                padding:const EdgeInsets.all(7),
                itemCount:rows.length,
                itemBuilder:(context,index){
                  final r=rows[index];
                  return Container(
                    margin:const EdgeInsets.only(bottom:5),
                    padding:const EdgeInsets.all(5),
                    decoration:BoxDecoration(border:Border.all(color:border),color:dark?const Color(0xff161a1c):const Color(0xfff5f5f2)),
                    child:Wrap(spacing:5,runSpacing:5,children:[
                      rowField(r.km,(v)=>r.km=v,'km',width:75),
                      rowField(r.speed,(v)=>r.speed=v,'V',width:60),
                      rowField(r.text,(v)=>r.text=v,'Betriebsstelle / Text',width:190),
                      rowField(r.arrival,(v)=>r.arrival=v,'Ank',width:72),
                      rowField(r.departure,(v)=>r.departure=v,'Abf',width:72),
                      rowField(r.kind,(v)=>r.kind=v,'Art',width:70),
                      rowField(r.track,(v)=>r.track=v,'Gl',width:55),
                      rowField(r.lat,(v)=>r.lat=v,'Lat',width:90),
                      rowField(r.lon,(v)=>r.lon=v,'Lon',width:90),
                      rowField(r.note,(v)=>r.note=v,'Hinweis',width:150),
                      SizedBox(width:36,height:36,child:IconButton(onPressed:()=>setLocal(()=>rows.removeAt(index)),icon:Icon(Icons.delete_outline,color:keyGlow,size:18),tooltip:'Zeile löschen')),
                    ]),
                  );
                },
              )),
              Container(
                padding:const EdgeInsets.all(8),
                decoration:BoxDecoration(border:Border(top:BorderSide(color:border)),color:bar),
                child:Row(children:[
                  const SizedBox(width:1),
                  Text('Streckendaten hinzufügen →',style:TextStyle(color:fg,fontSize:10,fontWeight:FontWeight.bold)),
                  const SizedBox(width:8),
                  _editorAddButton(context,setLocal,rows),
                  const Spacer(),
                  Text(notes.text.isEmpty?'':notes.text,style:TextStyle(color:fg,fontSize:9)),
                  const SizedBox(width:8),
                  TextButton(onPressed:saving?null:()=>Navigator.pop(dialogContext),child:Text('C',style:TextStyle(color:fg,fontWeight:FontWeight.bold))),
                  TextButton(onPressed:saving?null:() async {
                    setLocal(()=>saving=true);
                    final stops=<StopPoint>[];
                    for(final r in rows.reversed){
                      final kmVal=double.tryParse(r.km.replaceAll(',','.'));
                      if(kmVal==null || r.text.trim().isEmpty) continue;
                      stops.add(StopPoint(
                        name:r.text.trim(),km:kmVal,
                        speed:int.tryParse(r.speed.trim()),
                        arrival:r.arrival.trim().isEmpty?null:r.arrival.trim(),
                        departure:r.departure.trim().isEmpty?null:r.departure.trim(),
                        note:r.note.trim().isEmpty?null:r.note.trim(),
                        latitude:double.tryParse(r.lat.replaceAll(',','.')),
                        longitude:double.tryParse(r.lon.replaceAll(',','.')),
                        kind:r.kind.trim().isEmpty?null:r.kind.trim(),
                        track:r.track.trim().isEmpty?null:r.track.trim(),
                      ));
                    }
                    if(stops.isEmpty || trainNo.text.trim().isEmpty){
                      setLocal(()=>saving=false);
                      return;
                    }
                    final id=existing?.id??'custom-'+DateTime.now().millisecondsSinceEpoch.toString();
                    final data=TimetableData(
                      id:id,
                      trainNumber:trainNo.text.trim(),
                      service:route.text.trim(),
                      serviceType:trainNo.text.trim().startsWith('ICE')?'ICE':trainNo.text.trim().startsWith('IC')?'IC':'Regional',
                      serviceTypes:<String>[trainNo.text.trim().startsWith('ICE')?'ICE':trainNo.text.trim().startsWith('IC')?'IC':'Regional'],
                      validity:validity.text.trim(),
                      date:date.text.trim(),
                      vehicle:vehicle.text.trim(),
                      maxSpeed:int.tryParse(vmax.text.trim())??0,
                      lengthMeters:int.tryParse(length.text.trim())??0,
                      massTons:int.tryParse(mass.text.trim())??0,
                      brakeHundredths:brake.text.trim(),
                      pzbType:pzb.text.trim(),
                      notes:notes.text.trim(),
                      stops:stops,
                    );
                    await saveCustomTimetable(data,replaceId:existing?.id);
                    if(!mounted)return;
                    Navigator.pop(dialogContext);
                  },child:Text('E',style:TextStyle(color:keyGlow,fontWeight:FontWeight.bold))),
                ]),
              ),
            ]),
          ),
        );
      }),
    );

    for(final c in [trainNo,route,date,validity,vehicle,vmax,length,mass,brake,pzb,notes]) c.dispose();
  }

  Widget _editorAddButton(BuildContext context,void Function(void Function()) setLocal,List<_EditorRow> rows){
    return InkWell(
      onTap:()=>setLocal(()=>rows.insert(0,_EditorRow())),
      child:Container(
        height:34,padding:const EdgeInsets.symmetric(horizontal:13),
        alignment:Alignment.center,
        decoration:BoxDecoration(color:dark?const Color(0xff101214):const Color(0xffeef1f2),border:Border.all(color:border)),
        child:Text('HINZUFÜGEN',style:TextStyle(color:fg,fontSize:9,fontWeight:FontWeight.bold)),
      ),
    );
  }

  Future<void> saveCustomTimetable(TimetableData data,{String? replaceId}) async {
    final prefs=await SharedPreferences.getInstance();
    final current=<TimetableData>[...customTimetables];
    if(replaceId!=null){
      final idx=current.indexWhere((e)=>e.id==replaceId);
      if(idx>=0) current[idx]=data; else current.add(data);
    } else {
      current.add(data);
    }
    final jsonList=current.map((t)=>jsonEncode({
      'id':t.id,'trainNumber':t.trainNumber,'service':t.service,'serviceType':t.serviceType,
      'serviceTypes':t.serviceTypes,'validity':t.validity,'date':t.date,'vehicle':t.vehicle,
      'maxSpeed':t.maxSpeed,'lengthMeters':t.lengthMeters,'massTons':t.massTons,
      'brakeHundredths':t.brakeHundredths,'pzbType':t.pzbType,'notes':t.notes,
      'stops':t.stops.map((p)=>p.toJson()).toList(),
    })).toList();
    await prefs.setStringList('custom_timetables',jsonList);
    if(!mounted)return;
    applyCustomTimetableState(data,current);
  }
}
