import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'permissions.dart';

class ManageProjectsPage extends StatefulWidget {
  const ManageProjectsPage({super.key});

  @override
  State<ManageProjectsPage> createState() => _ManageProjectsPageState();
}

class _ManageProjectsPageState extends State<ManageProjectsPage> {
  // No persistent form; dialogs handle add/edit

  bool _permsLoading = true;
  bool _canView = false;
  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;
  // Horizontal scroll sync controllers (body drives header)
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
    _loadPerms();
  }

  @override
  void dispose() {
    _bodyHCtrl.dispose();
    _headerHCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPerms() async {
    try {
      final email = (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase().trim();
      final allowed = await PermissionsService.fetchAllowedKeysForEmail(email);
      setState(() {
        _canView = allowed.contains(PermKeys.projectsView);
  _canAdd = allowed.contains(PermKeys.projectsAdd) || allowed.contains(PermKeys.projectsEdit);
  _canEdit = allowed.contains(PermKeys.projectsEdit);
        _canDelete = allowed.contains(PermKeys.projectsDelete);
        _permsLoading = false;
      });
    } catch (e) {
      setState(() {
        _permsLoading = false;
        _canView = false;
        _canEdit = false;
        _canDelete = false;
      });
    }
  }

  Future<void> _openProjectDialog({String? id, String? currentName}) async {
    final isAdd = id == null;
    if (isAdd && !_canAdd) return;
    if (!isAdd && !_canEdit) return;
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController(text: currentName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'Add Project' : 'Edit Project'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Project Name'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter project name' : null,
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
                if (id == null) {
                  await FirebaseFirestore.instance.collection('projects').add({
                    'name': name,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } else {
                  await FirebaseFirestore.instance.collection('projects').doc(id).update({
                    'name': name,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id == null ? 'Project added' : 'Project updated')));
    }
  }

  Future<void> _delete(String id) async {
    if (!_canDelete) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('projects').doc(id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Widget _headerRow(double width) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: const [
          Expanded(flex: 2, child: Text('Project', style: TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text('Created', style: TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: Text('Updated', style: TextStyle(fontWeight: FontWeight.w700))),
          SizedBox(width: 40),
        ]),
      ),
    );
  }

  Widget _projectRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString();
    final created = (data['createdAt'] is Timestamp)
        ? (data['createdAt'] as Timestamp).toDate()
        : (data['createdAt'] is DateTime ? data['createdAt'] as DateTime : null);
    final updated = (data['updatedAt'] is Timestamp)
        ? (data['updatedAt'] as Timestamp).toDate()
        : (data['updatedAt'] is DateTime ? data['updatedAt'] as DateTime : null);
    String fmt(DateTime? d) => d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: .7,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _canEdit ? () => _openProjectDialog(id: doc.id, currentName: name) : null,
        onLongPress: _canDelete
            ? () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Project'),
                    content: const Text('Delete this project? This cannot be undone.'),
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
            Expanded(child: Text(fmt(created))),
            Expanded(child: Text(fmt(updated))),
            const SizedBox(width: 0),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_permsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_canView) {
      return const Center(child: Text('You do not have permission to view Projects.'));
    }

    return LayoutBuilder(
        builder: (context, constraints) {
          const minWidth = 800.0;
          final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
            children: [
              // Header (position synced)
              SingleChildScrollView(
                controller: _headerHCtrl,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(width: width, child: _headerRow(width)),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('projects').orderBy('name').snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('No projects'));
                    final rows = docs.map(_projectRow).toList();
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
              if (_canAdd)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: FloatingActionButton.extended(
                      heroTag: 'addProjectFab',
                      onPressed: () => _openProjectDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Project'),
                    ),
                  ),
                ),
            ],
          ),
          );
        },
      );
  }
}
