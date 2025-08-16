// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'permissions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Manage Template Goals (CRUD) similar to Branches list.
/// Permissions mimic Branch permissions (branchesView/Add/Edit/Delete) as requested.
class TemplateGoalsPanel extends StatefulWidget {
  final Set<String> allowed;
  final bool isAdmin;
  const TemplateGoalsPanel({super.key, required this.allowed, required this.isAdmin});

  @override
  State<TemplateGoalsPanel> createState() => _TemplateGoalsPanelState();
}

class _TemplateGoalsPanelState extends State<TemplateGoalsPanel> {
  bool get _canView => widget.isAdmin || widget.allowed.contains(PermKeys.branchesView);
  bool get _canAdd => widget.isAdmin || widget.allowed.contains(PermKeys.branchesAdd) || widget.allowed.contains(PermKeys.branchesEdit);
  bool get _canEdit => widget.isAdmin || widget.allowed.contains(PermKeys.branchesEdit);
  bool get _canDelete => widget.isAdmin || widget.allowed.contains(PermKeys.branchesDelete);

  // Cached person & branch metadata for resolving name and branch name from email
  final Map<String, Map<String, dynamic>> _personsByEmail = {}; // email -> data {name, branchId}
  final Map<String, String> _branchNames = {}; // branchId -> branch name
  StreamSubscription? _personsSub;
  StreamSubscription? _branchesSub;

  @override
  void initState() {
    super.initState();
    // Listen to persons collection for resolving names & branch IDs
    _personsSub = FirebaseFirestore.instance.collection('persons').snapshots().listen((snap) {
      for (final d in snap.docs) {
        final data = d.data();
        final email = (data['email'] ?? '').toString().toLowerCase();
        if (email.isNotEmpty) {
          _personsByEmail[email] = data;
        }
      }
      if (mounted) setState(() {});
    });
    // Listen to branches collection for resolving branch names
    _branchesSub = FirebaseFirestore.instance.collection('branches').snapshots().listen((snap) {
      for (final d in snap.docs) {
        final name = (d.data()['name'] ?? '').toString();
        _branchNames[d.id] = name;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _personsSub?.cancel();
    _branchesSub?.cancel();
    super.dispose();
  }

  Future<void> _openDialog({String? id, String? currentName, String? currentEmail, String? currentAssigneeName, String? currentBranchId, int? currentTemplateNumber, int? currentRemaining}) async {
    final isAdd = id == null;
    if (isAdd && !_canAdd) return; if (!isAdd && !_canEdit) return;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: currentName ?? '');
  final numberCtrl = TextEditingController(text: currentTemplateNumber != null ? currentTemplateNumber.toString() : '');
    String? selectedBranchId = currentBranchId;
    String? selectedPersonEmail = currentEmail;
    String resolvedAssigneeName = currentAssigneeName ?? '';
    void resolveFromPerson() {
      if (selectedPersonEmail == null || selectedPersonEmail!.isEmpty) {
        resolvedAssigneeName = '';
        return;
      }
      final pdata = _personsByEmail[selectedPersonEmail!.toLowerCase()];
      if (pdata != null) {
        resolvedAssigneeName = (pdata['name'] ?? '').toString();
        final bid = (pdata['branchId'] ?? '').toString();
        if (bid.isNotEmpty) selectedBranchId = bid; // sync branch if differs
      }
    }
    resolveFromPerson();
    bool saving = false;

  // Target (templateNumber) is user-defined; no auto-increment serial behavior now.
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        final user = FirebaseAuth.instance.currentUser;
        final userEmail = (user?.email ?? 'NOT SIGNED IN');
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isAdd ? 'Add Template Goal' : 'Edit Template Goal'),
              const SizedBox(height: 4),
              Text('Auth: $userEmail', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: numberCtrl,
                    decoration: const InputDecoration(labelText: 'Target (Total Planned)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter target';
                      if (int.tryParse(v.trim()) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Goal Name'),
                    autofocus: true,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter goal name' : null,
                  ),
                  const SizedBox(height: 12),
                  // Branch dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('branches').orderBy('name').snapshots(),
                    builder: (c, snap) {
                      final branches = snap.data?.docs ?? [];
                      return DropdownButtonFormField<String?>(
                        value: selectedBranchId,
                        decoration: const InputDecoration(labelText: 'Branch'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('No Branch')),
                          ...branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text((b['name'] ?? '').toString()))),
                        ],
                        onChanged: (v) => setM(() { selectedBranchId = v; }),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Assignee (Person) dropdown filtered by branch
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('persons').orderBy('name').snapshots(),
                    builder: (c, snap) {
                      final personsAll = snap.data?.docs ?? [];
                      final persons = personsAll.where((p) {
                        if (selectedBranchId == null) return true; // show all or restrict? requirement: when branch selected only show that branch
                        final bid = (p['branchId'] ?? '').toString();
                        return bid == selectedBranchId;
                      }).toList();
                      return DropdownButtonFormField<String?>(
                        value: selectedPersonEmail,
                        decoration: const InputDecoration(labelText: 'Assignee Name'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('No Assignee')),
                          ...persons.map((p) => DropdownMenuItem<String?>(
                                value: (p['email'] ?? '').toString().toLowerCase(),
                                child: Text((p['name'] ?? '').toString()),
                              )),
                        ],
                        onChanged: (v) => setM(() { selectedPersonEmail = v; resolveFromPerson(); }),
                      );
                    },
                  ),
                  if (resolvedAssigneeName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(resolvedAssigneeName, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setM(() => saving = true);
                try {
                  // Re-resolve person + branch
                  resolveFromPerson();
                  final branchId = selectedBranchId;
                  final targetVal = int.tryParse(numberCtrl.text.trim());
                  // Compute remaining automatically:
                  int? newRemaining;
                  if (isAdd) {
                    newRemaining = targetVal; // start remaining at target
                  } else {
                    // For edit: clamp existing remaining if higher than new target
                    if (currentRemaining != null && targetVal != null) {
                      newRemaining = currentRemaining > targetVal ? targetVal : currentRemaining;
                    } else {
                      newRemaining = currentRemaining; // may be null
                    }
                  }
                  final data = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'templateNumber': targetVal,
                    'remaining': newRemaining,
                    'assigneeEmail': selectedPersonEmail?.toLowerCase(),
                    'assigneeName': resolvedAssigneeName.isNotEmpty ? resolvedAssigneeName : null,
                    'branchId': branchId,
                    'updatedAt': FieldValue.serverTimestamp(),
                    if (isAdd) 'createdAt': FieldValue.serverTimestamp(),
                  };
                  final col = FirebaseFirestore.instance.collection('templateGoals');
                  if (isAdd) {
                    await col.add(data);
                  } else {
                    await col.doc(id).set(data, SetOptions(merge: true));
                  }
                  if (mounted) Navigator.pop(ctx, true);
        } catch (e) {
                  if (mounted) {
          final auth = FirebaseAuth.instance.currentUser;
          final dbg = 'uid=${auth?.uid ?? 'null'} email=${auth?.email ?? 'null'}';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e\n$dbg')));
                  }
                } finally {
                  if (mounted) setM(() => saving = false);
                }
              },
              child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isAdd ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAdd ? 'Template goal added' : 'Template goal updated')));
    }
  }

  Future<void> _delete(String id) async {
    if (!_canDelete) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Template Goal'),
        content: const Text('Delete this goal? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('templateGoals').doc(id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    return '—';
  }

  Widget _header(double width) => Card(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        elevation: 1,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(flex: 2, child: Text('Target', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Remaining', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 3, child: Text('Goal', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 3, child: Text('Assignee Name', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 3, child: Text('Branch', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 3, child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Created', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Updated', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 20),
          ]),
        ),
      );

  Widget _row(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
  final name = (data['name'] ?? '').toString();
  final tNum = data['templateNumber'];
  final tNumStr = (tNum is int || tNum is num) ? tNum.toString() : '—';
  final remaining = data['remaining'];
  final remainingStr = (remaining is int || remaining is num) ? remaining.toString() : '—';
    final email = (data['assigneeEmail'] ?? '').toString();
    final assigneeName = (data['assigneeName'] ?? '').toString().isNotEmpty
        ? (data['assigneeName'] ?? '').toString()
        : _personsByEmail[email.toLowerCase()] != null
            ? (_personsByEmail[email.toLowerCase()]!['name'] ?? '').toString()
            : '';
    final branchId = (data['branchId'] ?? '').toString();
    final branchName = branchId.isNotEmpty ? (_branchNames[branchId] ?? '') : '';
    final createdAt = _fmtTs(data['createdAt']);
    final updatedAt = _fmtTs(data['updatedAt']);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: .7,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
  onTap: _canEdit ? () => _openDialog(id: doc.id, currentName: name, currentEmail: email, currentAssigneeName: assigneeName, currentTemplateNumber: (tNum is int ? tNum : (tNum is num ? tNum.toInt() : null)), currentBranchId: branchId, currentRemaining: (data['remaining'] is int ? data['remaining'] : (data['remaining'] is num ? (data['remaining'] as num).toInt() : null))) : null,
        onLongPress: _canDelete
            ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Template Goal'),
                    content: const Text('Delete this goal? This cannot be undone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirm == true) {
                  _delete(doc.id);
                }
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(flex: 2, child: Text(tNumStr, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(flex: 2, child: Text(remainingStr, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(flex: 3, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(flex: 3, child: Text(assigneeName.isEmpty ? '—' : assigneeName)),
            Expanded(flex: 3, child: Text(branchName.isEmpty ? '—' : branchName)),
            Expanded(flex: 3, child: Text(email.isEmpty ? '—' : email)),
            Expanded(flex: 2, child: Text(createdAt)),
            Expanded(flex: 2, child: Text(updatedAt)),
            const SizedBox(width: 0),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return const Center(child: Text('You do not have permission to view Template Goals.'));
    }
    return LayoutBuilder(builder: (context, constraints) {
      const minWidth = 1200.0;
      final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
      return Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: width, child: _header(width)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('templateGoals').orderBy('name').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('No template goals'));
                final rows = docs.map(_row).toList();
                return Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (c, i) => rows[i],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_canAdd)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton.extended(
                  heroTag: 'addTemplateGoalFab',
                  onPressed: () => _openDialog(),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Add Goal'),
                ),
              ),
            ),
        ],
      );
    });
  }
}
