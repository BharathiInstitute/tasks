import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'permissions.dart'; // for PermKeys.leavesApprove

/// Employee leaves panel. Approvers can see everyone's requests; others only their own.
class LeavesPanel extends StatefulWidget {
  final Set<String>? allowed;
  final bool isAdmin;
  const LeavesPanel({super.key, this.allowed, this.isAdmin = false});

  @override
  State<LeavesPanel> createState() => _LeavesPanelState();
}

class _LeavesPanelState extends State<LeavesPanel> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  String _type = 'Casual Leave';
  DateTime? _from;
  DateTime? _to;

  String get _uid => _auth.currentUser?.uid ?? 'anon';
    bool get _canApprove => widget.isAdmin || (widget.allowed?.contains(PermKeys.leavesApprove) ?? false);

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick from and to dates')));
      return;
    }
    if (_to!.isBefore(_from!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To date can't be before From date")));
      return;
    }
    final user = _auth.currentUser;
    final rawEmail = (user?.email ?? '').trim();
    final rawName = (user?.displayName ?? '').trim();
    final name = rawName.isNotEmpty ? rawName : (rawEmail.isNotEmpty ? rawEmail.split('@').first : 'Employee');
    await _fs.collection('leave_requests').add({
      'uid': _uid,
      'email': rawEmail.toLowerCase(),
      'name': name,
      'type': _type,
      'fromDate': Timestamp.fromDate(DateTime(_from!.year, _from!.month, _from!.day)),
      'toDate': Timestamp.fromDate(DateTime(_to!.year, _to!.month, _to!.day)),
      'note': _noteCtrl.text.trim(),
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _formKey.currentState!.reset();
    setState(() {
      _type = 'Casual Leave';
      _from = null;
      _to = null;
      _noteCtrl.clear();
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Leaves', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: _requestsListView()),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _openRequestDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Leave'),
            ),
          )
        ],
      ),
    );
  }

  void _openRequestDialog(){
    showDialog(context: context, builder: (ctx){
      final compact = MediaQuery.of(ctx).size.width < 640;
      return AlertDialog(
        title: const Text('New Leave Request'),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if(!compact) Row(children:[
                    Expanded(child: _typeField()), const SizedBox(width:12),
                    Expanded(child: _fromField()), const SizedBox(width:12),
                    Expanded(child: _toField()),
                  ]) else ...[
                    _typeField(), const SizedBox(height:12), _fromField(), const SizedBox(height:12), _toField()
                  ],
                  const SizedBox(height:12),
                  TextFormField(controller: _noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText:'Note (optional)', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: (){ Navigator.pop(ctx); }, child: const Text('Cancel')),
          ElevatedButton(onPressed: () async { await _submit(); if(mounted && Navigator.canPop(ctx)) Navigator.pop(ctx); }, child: const Text('Submit')),
        ],
      );
    });
  }

  // Removed outer wrapper card: show list as individual cards like other panels.

  Widget _typeField(){
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: const InputDecoration(labelText:'Type', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value:'Casual Leave', child: Text('Casual Leave')),
        DropdownMenuItem(value:'Sick Leave', child: Text('Sick Leave')),
        DropdownMenuItem(value:'Privilege Leave', child: Text('Privilege Leave')),
      ],
      onChanged: (v)=> setState(()=> _type = v??'Casual Leave'),
    );
  }

  Widget _fromField(){
    return TextFormField(
      readOnly: true,
      decoration: const InputDecoration(labelText:'From', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
      controller: TextEditingController(text: _fmtDate(_from)),
      validator: (_)=> _from==null ? 'Pick a date' : null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: _from ?? now, firstDate: DateTime(now.year-1), lastDate: DateTime(now.year+2));
        if(picked!=null) setState(()=> _from = picked);
      },
    );
  }

  Widget _toField(){
    return TextFormField(
      readOnly: true,
      decoration: const InputDecoration(labelText:'To', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
      controller: TextEditingController(text: _fmtDate(_to)),
      validator: (_)=> _to==null ? 'Pick a date' : null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: _to ?? (_from ?? now), firstDate: DateTime(now.year-1), lastDate: DateTime(now.year+2));
        if(picked!=null) setState(()=> _to = picked);
      },
    );
  }

  // Removed legacy _historyList method in favor of scrolling ListView implementation.

  Widget _requestsListView(){
    // Wrap the existing column builder inside a ListView for scrolling in Expanded
    final base = _fs.collection('leave_requests');
    final stream = _canApprove
        ? base.orderBy('createdAt', descending: true).limit(200).snapshots()
        : base.where('uid', isEqualTo: _uid).limit(50).snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
  final docs = s.data?.docs ?? [];
  if (docs.isEmpty) return const Center(child: Text('No leave requests yet.'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final d = docs[i];
            final m = d.data();
            final from = (m['fromDate'] as Timestamp?)?.toDate();
            final to = (m['toDate'] as Timestamp?)?.toDate();
            final type = (m['type'] ?? '').toString();
            final status = (m['status'] ?? 'Pending').toString();
            final name = (m['name'] ?? '').toString();
            final email = (m['email'] ?? '').toString();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('$type  •  ${_fmtDate(from)} → ${_fmtDate(to)}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_canApprove && (name.isNotEmpty || email.isNotEmpty)) Text([if (name.isNotEmpty) name, if (email.isNotEmpty) email].join(' • ')),
                    if ((m['note'] ?? '').toString().isNotEmpty) Text((m['note']).toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: Container(
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(status),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmtDate(DateTime? dt){
    if(dt==null) return '--';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }

}

