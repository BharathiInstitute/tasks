import 'package:cloud_firestore/cloud_firestore.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
// unified layout imports
import 'package:firebase_auth/firebase_auth.dart';
import 'permissions.dart';

class ManagePersonsPage extends StatefulWidget {
  const ManagePersonsPage({super.key});

  @override
  State<ManagePersonsPage> createState() => _ManagePersonsPageState();
}

class _ManagePersonsPageState extends State<ManagePersonsPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _loadAllowedOnce(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final allowed = snap.data ?? {};
        final canView = allowed.contains(PermKeys.personsView);
        if (!canView) {
          return const Scaffold(body: Center(child: Text('You do not have permission to view Persons.')));
        }
    final canAdd = allowed.contains(PermKeys.personsAdd) || allowed.contains(PermKeys.personsEdit); // allow edit implies add
    final canEdit = allowed.contains(PermKeys.personsEdit);
        final canDelete = allowed.contains(PermKeys.personsDelete);
        // Removed internal AppBar (navigation bar) per request; parent screen provides top bar.
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ManagePersonsPanel(canAdd: canAdd, canEdit: canEdit, canDelete: canDelete),
        );
      },
    );
  }

  Future<Set<String>> _loadAllowedOnce() async {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    return PermissionsService.fetchAllowedKeysForEmail(email);
  }
}

class ManagePersonsPanel extends StatefulWidget {
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  const ManagePersonsPanel({super.key, required this.canAdd, required this.canEdit, required this.canDelete});

  @override
  State<ManagePersonsPanel> createState() => _ManagePersonsPanelState();
}

class _ManagePersonsPanelState extends State<ManagePersonsPanel> {
  // Horizontal scroll sync (body drives header)
  late final ScrollController _headerHCtrl;
  late final ScrollController _bodyHCtrl;

  @override
  void initState() {
    super.initState();
    _headerHCtrl = ScrollController();
    _bodyHCtrl = ScrollController();
    _bodyHCtrl.addListener(() {
      if (_headerHCtrl.hasClients && _headerHCtrl.offset != _bodyHCtrl.offset) {
        _headerHCtrl.jumpTo(_bodyHCtrl.offset);
      }
    });
  }

  @override
  void dispose() {
    _bodyHCtrl.dispose();
    _headerHCtrl.dispose();
    super.dispose();
  }
  Future<void> _openPersonDialog({String? id}) async {
  final isAdd = id == null;
  if (isAdd && !widget.canAdd) return; // cannot add
  if (!isAdd && !widget.canEdit) return; // cannot edit existing
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? branchId;
    if (id != null) {
      final doc = await FirebaseFirestore.instance.collection('persons').doc(id).get();
      final data = doc.data();
      if (data != null) {
        nameCtrl.text = (data['name'] ?? '').toString();
        emailCtrl.text = (data['email'] ?? '').toString();
        phoneCtrl.text = (data['phone'] ?? '').toString();
        branchId = data['branchId'];
      }
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        return AlertDialog(
          title: Text(id == null ? 'Add Person' : 'Edit Person'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Branch first
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('branches').orderBy('name').snapshots(),
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String?>(
                          value: branchId,
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('No Branch')),
                            ...docs.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text((d['name'] ?? '').toString()))),
                          ],
                          onChanged: (v) => setM(() => branchId = v),
                          decoration: const InputDecoration(labelText: 'Branch'),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    // Phone (number) before Email per request
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().length < 7 ? 'Enter phone' : null,
                    ),
                    const SizedBox(height: 12),
                    // Email
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Password last
                    TextFormField(
                      controller: passwordCtrl,
                      decoration: InputDecoration(labelText: id == null ? 'Password' : 'Password (leave blank to keep)'),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: (v) {
                        if (id == null) {
                          if (v == null || v.length < 6) return 'Min 6 chars';
                        } else {
                          if (v != null && v.isNotEmpty && v.length < 6) return 'Min 6 chars';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  // Upsert Auth user via callable Cloud Function
                  final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('adminUpsertUser');
                  final pw = passwordCtrl.text.trim();
                  try {
                    await callable.call({
                      'email': emailCtrl.text.trim().toLowerCase(),
                      if (pw.isNotEmpty) 'password': pw,
                      'displayName': nameCtrl.text.trim(),
                    });
                  } on FirebaseFunctionsException catch (fe) {
                    if (kDebugMode) {
                      debugPrint('Functions error code=${fe.code} message=${fe.message} details=${fe.details}');
                    }
                    rethrow;
                  }

                  final data = {
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim().toLowerCase(),
                    'phone': phoneCtrl.text.trim(),
                    'branchId': branchId,
                    'updatedAt': FieldValue.serverTimestamp(),
                    if (id == null) 'createdAt': FieldValue.serverTimestamp(),
                  };
                  final col = FirebaseFirestore.instance.collection('persons');
                  if (id == null) {
                    await col.add(data);
                  } else {
                    await col.doc(id).set(data, SetOptions(merge: true));
                  }
                  if (mounted) Navigator.pop(ctx, true);
        } catch (e) {
                  if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
                  }
                }
              },
              child: Text(id == null ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id == null ? 'Person added' : 'Person updated')));
    }
  }

  Future<void> _delete(String id) async {
    if (!widget.canDelete) return;
    try {
      await FirebaseFirestore.instance.collection('persons').doc(id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Widget _header() => Card(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        elevation: 1,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(flex: 2, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 3, child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Phone', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Branch', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(flex: 2, child: Text('Created', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 80),
          ]),
        ),
      );

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      return '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    return '—';
  }

  Widget _row(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final branchId = data['branchId'];
    final createdAt = _fmtTs(data['createdAt']);
    final updatedAtRaw = data['updatedAt'];
    return StreamBuilder<DocumentSnapshot>(
      stream: branchId == null ? null : FirebaseFirestore.instance.collection('branches').doc(branchId).snapshots(),
      builder: (context, snap) {
        final branchName = branchId == null
            ? '—'
            : (snap.data != null && snap.data!.data() != null)
                ? ((snap.data!['name'] ?? '').toString())
                : '...';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          elevation: .7,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.canEdit ? () => _openPersonDialog(id: doc.id) : null,
            onLongPress: widget.canDelete
                ? () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Delete Person'),
                        content: const Text('Delete this person? This cannot be undone.'),
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
                Expanded(flex: 2, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text(email)),
                Expanded(flex: 2, child: Text(phone.isEmpty ? '—' : phone)),
                Expanded(flex: 2, child: Text(branchName)),
                Expanded(flex: 2, child: Tooltip(message: updatedAtRaw is Timestamp ? 'Updated ${_fmtTs(updatedAtRaw)}' : 'No updates', child: Text(createdAt))),
                const SizedBox(width: 0), // placeholder to preserve layout height
              ]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
  const minWidth = 1100.0;
      final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
      return Column(children: [
        // Synced header (non-scrollable directly)
        SingleChildScrollView(
          controller: _headerHCtrl,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(width: width, child: _header()),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('persons').orderBy('name').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No persons'));
              final rows = docs.map(_row).toList();
              return Scrollbar(
                controller: _bodyHCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _bodyHCtrl,
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
  if (widget.canAdd)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton.extended(
                heroTag: 'addPersonFab',
                onPressed: () => _openPersonDialog(),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Person'),
              ),
            ),
          )
      ]);
    });
  }
}
