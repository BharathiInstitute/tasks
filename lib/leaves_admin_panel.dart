import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// Approvals permissions removed; panel now read-only (could be deleted if unused).

/// Administrative leave approvals panel.
/// Shows recent leave requests (optionally filtered) and allows approvers to
/// approve / reject / reset, adjusting balances on approval.
/// Non-approvers (opened via nav guard) will see list without action buttons.

class LeavesAdminPanel extends StatefulWidget {
  final Set<String> allowed;
  final bool isAdmin;
  const LeavesAdminPanel({super.key, required this.allowed, this.isAdmin = false});

  @override
  State<LeavesAdminPanel> createState() => _LeavesAdminPanelState();
}

class _LeavesAdminPanelState extends State<LeavesAdminPanel> {
  final _fs = FirebaseFirestore.instance;
  String _statusFilter = 'All';
  String _typeFilter = 'All';
  final Map<String, Map<String,String>> _userCache = {}; // uid -> {name,email}
  bool _didCleanupLegacy = false;

  Future<void> _maybeCleanupLegacy(List<QueryDocumentSnapshot<Map<String,dynamic>>> docs) async {
    if(_didCleanupLegacy) return; // run once per panel mount
    // Legacy docs: missing BOTH name and email fields (empty or absent)
    final legacy = docs.where((d){
      final m = d.data();
      final name = (m['name']??'').toString().trim();
      final email = (m['email']??'').toString().trim();
      return name.isEmpty && email.isEmpty; // only delete if both absent -> clearly old format
    }).toList();
    if(legacy.isEmpty) { _didCleanupLegacy = true; return; }
    try {
      // Limit deletes to avoid large batch issues
      final toDelete = legacy.take(50).toList();
      final batch = _fs.batch();
      for(final d in toDelete){ batch.delete(d.reference); }
      await batch.commit();
    } catch(_){ /* ignore cleanup errors */ }
    _didCleanupLegacy = true; // prevent repeated deletion loops
  }

  Stream<QuerySnapshot<Map<String,dynamic>>> _stream(){
    var q = _fs.collection('leave_requests').orderBy('createdAt', descending: true).limit(200);
    if(_statusFilter != 'All'){
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.snapshots();
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children:[
          const Text('Leave Requests', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width:16),
          DropdownButton<String>(value: _statusFilter, items: const [
            DropdownMenuItem(value:'All', child: Text('All')),
            DropdownMenuItem(value:'Pending', child: Text('Pending')),
            DropdownMenuItem(value:'Approved', child: Text('Approved')),
            DropdownMenuItem(value:'Rejected', child: Text('Rejected')),
          ], onChanged:(v)=> setState(()=> _statusFilter = v??'All')),
          const SizedBox(width:12),
          DropdownButton<String>(value: _typeFilter, items: const [
            DropdownMenuItem(value:'All', child: Text('All Types')),
            DropdownMenuItem(value:'Casual', child: Text('Casual')),
            DropdownMenuItem(value:'Sick', child: Text('Sick')),
            DropdownMenuItem(value:'Privilege', child: Text('Privilege')),
          ], onChanged:(v)=> setState(()=> _typeFilter = v??'All')),
        ]),
        const SizedBox(height:12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream: _stream(),
            builder:(c,s){
              if(s.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
              var docs = s.data?.docs ?? [];
              // Trigger one-time legacy cleanup (fire & forget)
              if(docs.isNotEmpty) { _maybeCleanupLegacy(docs); }
              if(_typeFilter!='All'){
                docs = docs.where((d){ final t=(d.data()['type']??'').toString(); return t.contains(_typeFilter); }).toList();
              }
              if(docs.isEmpty) return const Center(child: Text('No requests'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder:(c,i){
                  final d = docs[i];
                  final m = d.data();
                  final type=(m['type']??'').toString();
                  final status=(m['status']??'Pending').toString();
                  final uid=(m['uid']??'').toString();
                  String name=(m['name']??'').toString();
                  String email=(m['email']??'').toString();
                  // Lazy lookup if missing
                  if(uid.isNotEmpty && (name.isEmpty && email.isEmpty)){
                    final cached = _userCache[uid];
                    if(cached!=null){
                      name = cached['name']??''; email = cached['email']??'';
                    } else {
                      // Fire off async lookup; rebuild when done
                      _fs.collection('persons').where('uid', isEqualTo: uid).limit(1).get().then((snap){
                        if(!mounted || snap.docs.isEmpty) return;
                        final data = snap.docs.first.data();
                        final nm = (data['name']??'').toString();
                        final em = (data['email']??'').toString();
                        _userCache[uid] = {'name': nm, 'email': em};
                        if(name.isEmpty && email.isEmpty){
                          setState((){}); // trigger rebuild to display fetched data
                        }
                      }).catchError((_){ });
                    }
                  }
          final note=(m['note']??'').toString();
          final from=(m['fromDate'] as Timestamp?)?.toDate();
          final to=(m['toDate'] as Timestamp?)?.toDate();
                  Widget subtitle(){
                    final lines=<Widget>[];
                    if(name.isNotEmpty || email.isNotEmpty){
                      final display = [if(name.isNotEmpty) name, if(email.isNotEmpty) email].join('  •  ');
                      lines.add(Text(display));
                    } else {
                      lines.add(Text('User: $uid', style: const TextStyle(color: Colors.black54)));
                    }
                    if(note.isNotEmpty) lines.add(Text(note, maxLines:2, overflow: TextOverflow.ellipsis));
                    lines.add(Text('Status: $status'));
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical:4),
                    child: ListTile(
            title: Text('$type  •  ${_fmtDate(from)} → ${_fmtDate(to)}'),
                      subtitle: subtitle(),
                      trailing: null, // actions removed
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // _actions removed

  String _fmtDate(DateTime? dt){
    if(dt==null) return '--';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }
}
