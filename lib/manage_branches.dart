import 'package:cloud_firestore/cloud_firestore.dart';
// responsive.dart no longer needed after layout refactor
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'permissions.dart';

class ManageBranchesPage extends StatefulWidget {
  const ManageBranchesPage({super.key});

  @override
  State<ManageBranchesPage> createState() => _ManageBranchesPageState();
}

class _ManageBranchesPageState extends State<ManageBranchesPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _loadAllowedOnce(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final allowed = snap.data ?? {};
        final canView = allowed.contains(PermKeys.branchesView);
        if (!canView) {
          return const Scaffold(body: Center(child: Text('You do not have permission to view Branches.')));
        }
    final canAdd = allowed.contains(PermKeys.branchesAdd) || allowed.contains(PermKeys.branchesEdit);
    final canEdit = allowed.contains(PermKeys.branchesEdit);
        final canDelete = allowed.contains(PermKeys.branchesDelete);
        // Removed internal AppBar to avoid nested headers; parent screen provides top bar.
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: ManageBranchesPanel(canAdd: canAdd, canEdit: canEdit, canDelete: canDelete),
        );
      },
    );
  }

  Future<Set<String>> _loadAllowedOnce() async {
    final email = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
    return PermissionsService.fetchAllowedKeysForEmail(email);
  }
}

class ManageBranchesPanel extends StatefulWidget {
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  const ManageBranchesPanel({super.key, required this.canAdd, required this.canEdit, required this.canDelete});

  @override
  State<ManageBranchesPanel> createState() => _ManageBranchesPanelState();
}

class _ManageBranchesPanelState extends State<ManageBranchesPanel> {
  // Horizontal scroll sync (body -> header)
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
  Future<void> _openBranchDialog({String? id, String? currentName}) async {
  final isAdd = id == null;
  if (isAdd && !widget.canAdd) return;
  if (!isAdd && !widget.canEdit) return;
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(text: currentName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'Add Branch' : 'Edit Branch'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Branch Name'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter branch name' : null,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final name = ctrl.text.trim();
                final col = FirebaseFirestore.instance.collection('branches');
                if (id == null) {
                  await col.add({'name': name});
                } else {
                  await col.doc(id).update({'name': name});
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
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id == null ? 'Branch added' : 'Branch updated')));
    }
  }

  Future<void> _delete(String id) async {
    if (!widget.canDelete) return;
    try {
      await FirebaseFirestore.instance.collection('branches').doc(id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  // Header removed per request.
  Widget _header() => Card(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        elevation: 1,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
      Expanded(flex: 3, child: Text('Branch', style: TextStyle(fontWeight: FontWeight.w700)) ),
            SizedBox(width: 40),
          ]),
        ),
      );

  Widget _row(QueryDocumentSnapshot doc) {
    final name = (doc['name'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: .7,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.canEdit ? () => _openBranchDialog(id: doc.id, currentName: name) : null,
        onLongPress: widget.canDelete
            ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Branch'),
                    content: const Text('Delete this branch? This cannot be undone.'),
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
            Expanded(flex: 3, child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 0)
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const minWidth = 500.0;
      final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
      return Column(children: [
        // Synced header (not directly scrollable)
        SingleChildScrollView(
          controller: _headerHCtrl,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(width: width, child: _header()),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('branches').orderBy('name').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No branches'));
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
                heroTag: 'addBranchFab',
                onPressed: () => _openBranchDialog(),
                icon: const Icon(Icons.add_business),
                label: const Text('Add Branch'),
              ),
            ),
          ),
      ]);
    });
  }
}
