import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Attendance list in tasks-style tabular layout.
class AttendancePanel extends StatefulWidget {
  const AttendancePanel({super.key});
  @override
  State<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<AttendancePanel> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _busy = false;
  final DateTime _today = DateTime.now();

  String get _uid => _auth.currentUser?.uid ?? 'anon';
  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String get _todayKey => _dateKey(_today);
  // Display format dd/MM/yyyy (storage keeps yyyy-MM-dd for sorting & queries)
  String _displayDate(String key){
    if(key.length>=10){
      final parts = key.split('-');
      if(parts.length>=3){
        final yy = parts[0];
        final mm = parts[1];
        final dd = parts[2];
        if(dd.isNotEmpty && mm.isNotEmpty && yy.isNotEmpty){
          return '$dd/$mm/$yy';
        }
      }
    }
    return key;
  }
  DocumentReference<Map<String,dynamic>> _docFor(String key)=> _fs.collection('attendance').doc('${_uid}_$key');

  static const _officeLat = 17.457853, _officeLng = 78.422442, _officeRadius = 300.0;

  Future<({double? distance,bool? inside})> _loc() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return (distance:null, inside:null);
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final dist = Geolocator.distanceBetween(pos.latitude,pos.longitude,_officeLat,_officeLng);
      return (distance: dist, inside: dist <= _officeRadius);
    } catch(_){ return (distance:null, inside:null);} }

  Future<void> _ensureAuth() async { if (_auth.currentUser==null) await _auth.signInAnonymously(); }

  Future<void> _clock({required bool inPunch}) async {
    if(_busy) return; setState(()=>_busy=true);
    try {
      await _ensureAuth();
      final key = _todayKey;
      final doc = _docFor(key);
      final snap = await doc.get();
      final email = (_auth.currentUser?.email??'').toLowerCase();
      if(!snap.exists){
        await doc.set({'uid':_uid,'email':email,'dateKey':key,'createdAt':FieldValue.serverTimestamp()}, SetOptions(merge:true));
      } else if(((snap.data()?['email'])??'').toString().isEmpty && email.isNotEmpty){
        await doc.set({'email':email}, SetOptions(merge:true));
      }
      final last = await doc.collection('punches').orderBy('at', descending:true).limit(1).get();
      final lastType = last.docs.isNotEmpty ? (last.docs.first.data()['type']??'').toString() : '';
      if(inPunch && lastType=='in'){ _snack('Already clocked in'); return; }
      if(!inPunch && lastType!='in'){ _snack('Clock in first'); return; }
      final ls = await _loc();
      await doc.collection('punches').add({
        'type': inPunch ? 'in':'out',
        'at': Timestamp.now(),
        'insideOffice': ls.inside,
        'distanceMeters': ls.distance,
      });
      await doc.set({'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge:true));
      _snack(inPunch ? 'Clocked in':'Clocked out');
    } catch(e){ _snack('Failed: $e'); }
    finally { if(mounted) setState(()=>_busy=false); }
  }

  void _snack(String m){ if(!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        _monthSummary(),
        const SizedBox(height:12),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
          stream: _docFor(_todayKey).collection('punches').orderBy('at').snapshots(),
          builder:(c,s){
            final punches = s.data?.docs ?? [];
            final lastType = punches.isNotEmpty ? (punches.last.data()['type']??'').toString() : '';
            return Row(children:[
              ElevatedButton(
                onPressed: lastType=='in'||_busy?null:()=>_clock(inPunch:true),
                child: _busy && lastType!='in'
                    ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                    : const Text('Clock In'),
              ),
              const SizedBox(width:8),
              ElevatedButton(
                onPressed: lastType=='in'&&!_busy?()=>_clock(inPunch:false):null,
                child: _busy && lastType=='in'
                    ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                    : const Text('Clock Out'),
              ),
              const SizedBox(width:24),
              if(_busy) const Padding(
                padding: EdgeInsets.only(right:12),
                child: SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)),
              ),
              Text('Today: ${_displayDate(_todayKey)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]);
          }),
        const SizedBox(height:16),
        _headerRow(),
        const SizedBox(height:4),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream: _fs.collection('attendance').where('uid', isEqualTo: _uid).snapshots(),
            builder:(c,snap){
              if(snap.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if(docs.isEmpty) return const Center(child: Text('No attendance records'));
              docs.sort((a,b)=> (b.data()['dateKey']??'').toString().compareTo((a.data()['dateKey']??'').toString()));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder:(c,i)=> _dayRow(docs[i]),
              );
            },
          ),
        )
      ]),
    );
  }

  Widget _headerRow() => Card(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        elevation: 1,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('In', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('In Loc', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Out', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Out Loc', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Worked', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
        ),
      );

  Widget _dayRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final dateKey = (data['dateKey'] ?? '').toString();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: doc.reference.collection('punches').orderBy('at').snapshots(),
        builder: (c, s) {
          final punches = s.data?.docs ?? [];
            // Build in/out pairs
          final pairs = <_Pair>[];
          DateTime? openIn;
          bool? openInInside;
          for (final p in punches) {
            final pd = p.data();
            final type = (pd['type'] ?? '').toString();
            final at = (pd['at'] as Timestamp?)?.toDate();
            final inside = pd['insideOffice'] as bool?;
            if (type == 'in') {
              openIn = at;
              openInInside = inside;
            } else if (type == 'out') {
              if (openIn != null && at != null) {
                pairs.add(_Pair(inAt: openIn, outAt: at, inInside: openInInside, outInside: inside));
                openIn = null;
                openInInside = null;
              }
            }
          }
          if (openIn != null) {
            pairs.add(_Pair(inAt: openIn, outAt: null, inInside: openInInside, outInside: null));
          }
          Duration dayTotal = Duration.zero;
          for (final p in pairs) {
            if (p.outAt != null) dayTotal += p.outAt!.difference(p.inAt);
          }
          String tt(DateTime? d) {
            if (d == null) return '—';
            return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
          }
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: .7,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(_displayDate(dateKey),
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueGrey.shade200)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text('Day Total: ${_fmtDuration(dayTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    )
                  ]),
                  const SizedBox(height: 6),
                  ...pairs.asMap().entries.map((e) {
                    final idx = e.key;
                    final p = e.value;
                    final worked = p.outAt == null
                        ? 'Open'
                        : _fmtDuration(p.outAt!.difference(p.inAt));
                    return Padding(
                      padding: EdgeInsets.only(top: idx == 0 ? 0 : 6),
                      child: Row(children: [
                        Expanded(flex: 2, child: Text(idx == 0 ? '' : '')),
                        Expanded(flex: 2, child: Text(tt(p.inAt))),
                        Expanded(flex: 2, child: _locText(p.inInside)),
                        Expanded(flex: 2, child: Text(tt(p.outAt))),
                        Expanded(flex: 2, child: _locText(p.outInside)),
                        Expanded(flex: 2, child: Text(worked)),
                      ]),
                    );
                  }),
                ],
              ),
            ),
          );
        });
  }

  Widget _locText(bool? inside) {
    if (inside == null) return const Text('-');
    return Text(inside ? 'Inside' : 'Outside',
        style: TextStyle(color: inside ? Colors.teal.shade700 : Colors.orange.shade700));
  }

  // _locDot removed in new multi-entry layout (location shown as text)

  Widget _monthSummary(){
    final now = DateTime.now();
    return FutureBuilder<Duration>(
      future: _computeMonthTotal(now.year, now.month),
      builder:(c,s){ final d = s.data ?? Duration.zero; return Row(children:[
        Text(_monthLabel(now), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width:12),
        Container(decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade200)), padding: const EdgeInsets.symmetric(horizontal:10, vertical:6), child: Text('Month total: ${_fmtDuration(d)}', style: const TextStyle(fontWeight: FontWeight.w700))),
      ]); });
  }

  Future<Duration> _computeMonthTotal(int year,int month) async {
    Duration total = Duration.zero;
    try {
      final snap = await _fs.collection('attendance').where('uid', isEqualTo: _uid).get();
      for(final d in snap.docs){
        final dk = (d.data()['dateKey']??'').toString();
        if(dk.length<10) continue; final parts = dk.split('-'); if(parts.length<3) continue;
        final yy = int.tryParse(parts[0]); final mm = int.tryParse(parts[1]); if(yy!=year || mm!=month) continue;
        final punches = await d.reference.collection('punches').orderBy('at').get();
        DateTime? pending; for(final p in punches.docs){ final dt = (p.data()['at'] as Timestamp?)?.toDate(); final type=(p.data()['type']??'').toString(); if(type=='in'){ pending = dt; } else if(type=='out'){ if(pending!=null && dt!=null){ total += dt.difference(pending); pending=null; } } }
      }
    } catch(_){ }
    return total;
  }

  String _monthLabel(DateTime d){ const m=['January','February','March','April','May','June','July','August','September','October','November','December']; return '${m[d.month-1]} ${d.year}'; }
  String _fmtDuration(Duration dur){ final h = dur.inHours; final m = dur.inMinutes.remainder(60); return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} hrs'; }
}

class _Pair {
  final DateTime inAt;
  final DateTime? outAt;
  final bool? inInside;
  final bool? outInside;
  _Pair({required this.inAt, this.outAt, this.inInside, this.outInside});
}
