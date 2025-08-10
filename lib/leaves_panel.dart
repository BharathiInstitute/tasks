import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'responsive.dart';

class LeavesPanel extends StatefulWidget {
  const LeavesPanel({super.key});

  @override
  State<LeavesPanel> createState() => _LeavesPanelState();
}

class _LeavesPanelState extends State<LeavesPanel> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  String _type = 'Casual Leave';
  DateTime? _from;
  DateTime? _to;

  String get _uid => _auth.currentUser?.uid ?? 'anon';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('To date can\'t be before From date')));
      return;
    }
  await _firestore.collection('leave_requests').add({
      'uid': _uid,
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
  // Tiny delay so Firestore snapshot emits and the list updates without navigating
  await Future<void>.delayed(const Duration(milliseconds: 50));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted')));
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaves', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!compact)
                          Row(children: [
                            Expanded(child: _typeField()),
                            const SizedBox(width: 12),
                            Expanded(child: _fromField()),
                            const SizedBox(width: 12),
                            Expanded(child: _toField()),
                          ])
                        else ...[
                          _typeField(),
                          const SizedBox(height: 12),
                          _fromField(),
                          const SizedBox(height: 12),
                          _toField(),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Reason or context', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _historyList(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black12)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _balancesHolidays(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeField() {
    return DropdownButtonFormField<String>(
      value: _type,
      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
      items: const [
        DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
        DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave')),
        DropdownMenuItem(value: 'Privilege Leave', child: Text('Privilege Leave')),
      ],
      onChanged: (v) => setState(() => _type = v ?? 'Casual Leave'),
    );
  }

  Widget _fromField() {
    return TextFormField(
      readOnly: true,
      decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
      controller: TextEditingController(text: _fmtDate(_from)),
      validator: (_) => _from == null ? 'Pick a date' : null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: _from ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
        if (picked != null) setState(() => _from = picked);
      },
    );
  }

  Widget _toField() {
    return TextFormField(
      readOnly: true,
      decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
      controller: TextEditingController(text: _fmtDate(_to)),
      validator: (_) => _to == null ? 'Pick a date' : null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(context: context, initialDate: _to ?? (_from ?? now), firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
        if (picked != null) setState(() => _to = picked);
      },
    );
  }

  Widget _historyList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('leave_requests')
          .where('uid', isEqualTo: _uid)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        // Sort locally to avoid requiring a composite index; newest first
        docs.sort((a, b) {
          final at = (a.data()['createdAt'] as Timestamp?);
          final bt = (b.data()['createdAt'] as Timestamp?);
          final ad = at?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = bt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pending/History', style: TextStyle(fontWeight: FontWeight.w700)),
            const Divider(),
            if (docs.isEmpty)
              const Text('No leave requests yet.')
            else ...docs.map((d) {
              final m = d.data();
              final from = (m['fromDate'] as Timestamp?)?.toDate();
              final to = (m['toDate'] as Timestamp?)?.toDate();
              final t = (m['type'] ?? '').toString();
              final st = (m['status'] ?? 'Pending').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Chip(label: Text(t)),
                    const SizedBox(width: 8),
                    Text('${_fmtDate(from)} → ${_fmtDate(to)}'),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(st),
                    ),
                  ],
                ),
              );
            })
          ],
        );
      },
    );
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _balancesHolidays() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Balances & Holidays', style: TextStyle(fontWeight: FontWeight.w700)),
        const Divider(),
        // Balances
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('leave_balances').doc(_uid).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {'casual': 6, 'sick': 6, 'privilege': 12};
            final casual = (data['casual'] ?? 6).toString();
            final sick = (data['sick'] ?? 6).toString();
            final privilege = (data['privilege'] ?? 12).toString();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Balances (You)'),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  _balancePill('Casual Leave', casual),
                  _balancePill('Sick Leave', sick),
                  _balancePill('Privilege Leave', privilege),
                ]),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text('Holiday calendar (sample)'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('holidays')
              .orderBy('date')
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Text('No holidays configured.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: docs.map((d) {
                final m = d.data();
                final dt = (m['date'] as Timestamp?)?.toDate();
                final name = (m['name'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• ${_fmtDate(dt)} — $name'),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _balancePill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
