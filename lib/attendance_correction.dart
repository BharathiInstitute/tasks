import 'package:cloud_firestore/cloud_firestore.dart';
// ignore_for_file: use_build_context_synchronously, unnecessary_underscores
import 'package:flutter/material.dart';

/// Admin attendance correction screen.
/// Pass an email via Navigator arguments (String) or pushNamed with arguments.
class AttendanceCorrectionPage extends StatefulWidget {
  final String? initialEmail;
  const AttendanceCorrectionPage({super.key, this.initialEmail});

  @override
  State<AttendanceCorrectionPage> createState() => _AttendanceCorrectionPageState();
}

class _AttendanceCorrectionPageState extends State<AttendanceCorrectionPage> {
  final _firestore = FirebaseFirestore.instance;
  String? _email;
  List<QueryDocumentSnapshot<Map<String,dynamic>>> _personDocs = [];

  String _fmtDateKey(String key){
    if(key.length>=10){
      final parts = key.split('-');
      if(parts.length>=3){
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    return key;
  }

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail;
    _loadPersons();
  }

  Future<void> _loadPersons() async {
    try {
      final snap = await _firestore.collection('persons').orderBy('email').get();
      _personDocs = snap.docs;
      if (_email == null && _personDocs.isNotEmpty) _email = (_personDocs.first['email']??'').toString().toLowerCase();
      setState((){});
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String,dynamic>>> _attendanceStream() {
  // Always show recent attendance docs; email filtering applied client-side.
  return _firestore.collection('attendance').orderBy('dateKey', descending: true).limit(200).snapshots();
  }

  Future<void> _editDay(DocumentSnapshot<Map<String,dynamic>> dayDoc) async {
    final punchesSnap = await dayDoc.reference.collection('punches').orderBy('at').get();
    final punches = punchesSnap.docs.map((d)=> _PunchEdit(ref: d.reference, data: Map<String,dynamic>.from(d.data())) ).toList();
    final currentData = dayDoc.data() ?? <String,dynamic>{};
    final emailCtrl = TextEditingController(text: (currentData['email']??'').toString());
    await showDialog(context: context, builder: (ctx){
      return StatefulBuilder(builder: (ctx, setM){
        Future<void> saveChanges() async {
          for(final p in punches){
            await p.ref.set(p.data, SetOptions(merge: true));
          }
          final newEmail = emailCtrl.text.trim();
          if(newEmail.isNotEmpty && newEmail != (currentData['email']??'')){
            await dayDoc.reference.set({'email': newEmail.toLowerCase()}, SetOptions(merge: true));
          }
        }
        return AlertDialog(
          title: Text('Edit ${(currentData['dateKey']??'')}'),
          content: SizedBox(
            width: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email for this day (optional)'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: punches.length,
                    itemBuilder: (c,i){
                      final p = punches[i];
                      final data = p.data;
                      final ts = data['at'] as Timestamp?;
                      DateTime dt = ts?.toDate() ?? DateTime.now();
                      return Card(
                        child: ListTile(
                          title: Text('${data['type']}'),
                          subtitle: Text(dt.toLocal().toString()),
                          trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: dt, firstDate: DateTime(2023), lastDate: DateTime(2100));
                            if (picked==null) return; 
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dt));
                            if (time==null) return;
                            dt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                            p.data['at'] = Timestamp.fromDate(dt);
                            setM((){});
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(onPressed: () async { await saveChanges(); if(mounted) Navigator.pop(ctx); }, child: const Text('Save')),
          ],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Correction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children:[
              Expanded(
                child: DropdownButton<String>(
                  value: _email ?? '__all__',
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '__all__', child: Text('All (recent)')),
                    ..._personDocs.map((d){
                      final e = (d['email']??'').toString();
                      return DropdownMenuItem(value: e, child: Text(e));
                    })
                  ],
                  onChanged: (v){ setState(()=> _email = (v=='__all__') ? null : v); },
                ),
              ),
              IconButton(onPressed: _loadPersons, icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                stream: _attendanceStream(),
                builder: (context, snap){
                  if (snap.connectionState==ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No attendance records.'));
                  var docs = snap.data!.docs;
                  if(_email!=null && _email!.isNotEmpty){
                    docs = docs.where((d){ final data = d.data(); return (data['email']??'').toString()==_email; }).toList();
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __)=> const Divider(height: 1),
                    itemBuilder: (c,i){
                      final d = docs[i];
                      final data = d.data();
                      final dateKey = (data['dateKey']??'').toString();
                      final email = (data['email']??'').toString();
                      final uid = (data['uid']??'').toString();
                      return Card(
                        elevation: .5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12,10,12,10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Text(_fmtDateKey(dateKey), style: const TextStyle(fontWeight: FontWeight.w600))),
                                  IconButton(onPressed: ()=>_editDay(d), icon: const Icon(Icons.edit, size:18)),
                                ],
                              ),
                              if(email.isNotEmpty) Text('Email: $email', style: const TextStyle(fontSize:12)),
                              Text('UID: $uid', style: const TextStyle(fontSize:12)),
                              Tooltip(message: d.id, child: const Text('Doc ID', style: TextStyle(fontSize:12, fontStyle: FontStyle.italic))),
                              const SizedBox(height:6),
                              StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                                stream: d.reference.collection('punches').orderBy('at').snapshots(),
                                builder:(ctx, ps){
                                  if(ps.connectionState==ConnectionState.waiting){
                                    return const SizedBox(height:24, child: Center(child: CircularProgressIndicator(strokeWidth:1.5)));
                                  }
                                  final punches = ps.data?.docs ?? [];
                                  if(punches.isEmpty) return const Text('No punches');
                                  String fmtTime(DateTime? dt){
                                    if(dt==null) return '--:--';
                                    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
                                  }
                                  String fmtDur(Duration d){
                                    final h = d.inHours;
                                    final m = d.inMinutes.remainder(60);
                                    return "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";
                                  }
                                  // Build pairs
                                  DateTime? openIn; bool? openInInside; final pairs=<({DateTime inAt, DateTime? outAt, bool? inInside, bool? outInside})>[];
                                  for(final p in punches){
                                    final pd = p.data();
                                    final type = (pd['type']??'').toString();
                                    final at = (pd['at'] as Timestamp?)?.toDate();
                                    final inside = pd['insideOffice'] as bool?;
                                    if(type=='in'){
                                      openIn = at; openInInside = inside;
                                    } else if(type=='out') {
                                      if(openIn!=null){
                                        pairs.add((inAt: openIn, outAt: at, inInside: openInInside, outInside: inside));
                                        openIn=null; openInInside=null;
                                      }
                                    }
                                  }
                                  if(openIn!=null){
                                    pairs.add((inAt: openIn, outAt: null, inInside: openInInside, outInside: null));
                                  }
                                  Duration dayTotal = Duration.zero;
                                  for(final p in pairs){ if(p.outAt!=null) dayTotal += p.outAt!.difference(p.inAt); }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children:[
                                        const SizedBox(width:60, child: Text('IN', style: TextStyle(fontWeight: FontWeight.w600))),
                                        const SizedBox(width:60, child: Text('OUT', style: TextStyle(fontWeight: FontWeight.w600))),
                                        const SizedBox(width:70, child: Text('DUR', style: TextStyle(fontWeight: FontWeight.w600))),
                                        const SizedBox(width:70, child: Text('IN LOC', style: TextStyle(fontWeight: FontWeight.w600))),
                                        const Text('OUT LOC', style: TextStyle(fontWeight: FontWeight.w600)),
                                      ]),
                                      const SizedBox(height:4),
                                      ...pairs.map((p){
                                        Color locColor(bool? inside){
                                          if(inside==null) return Colors.blueGrey;
                                          return inside? Colors.teal.shade700 : Colors.orange.shade700;
                                        }
                                        String locTxt(bool? inside){
                                          if(inside==null) return '?';
                                          return inside? 'Inside':'Outside';
                                        }
                                        final dur = p.outAt?.difference(p.inAt);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical:2),
                                          child: Row(children:[
                                            SizedBox(width:60, child: Text(fmtTime(p.inAt), style: const TextStyle(fontFeatures:[FontFeature.tabularFigures()]))),
                                            SizedBox(width:60, child: Text(fmtTime(p.outAt), style: const TextStyle(fontFeatures:[FontFeature.tabularFigures()]))),
                                            SizedBox(width:70, child: Text(dur==null? 'Open' : fmtDur(dur), style: const TextStyle(fontFeatures:[FontFeature.tabularFigures()]))),
                                            SizedBox(width:70, child: Text(locTxt(p.inInside), style: TextStyle(color: locColor(p.inInside), fontSize:12))),
                                            Text(locTxt(p.outInside), style: TextStyle(color: locColor(p.outInside), fontSize:12)),
                                          ]),
                                        );
                                      }),
                                      const SizedBox(height:6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blueGrey.shade200),
                                        ),
                                        child: Text('Day Total: ${fmtDur(dayTotal)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper wrapper to allow editing list replacement; provides a fake snapshot-like object.
class _PunchEdit { final DocumentReference ref; final Map<String,dynamic> data; _PunchEdit({required this.ref, required this.data}); }
