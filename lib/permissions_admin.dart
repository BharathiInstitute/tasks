import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'permissions.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PermissionsAdminPanel extends StatefulWidget {
  const PermissionsAdminPanel({super.key});

  @override
  State<PermissionsAdminPanel> createState() => _PermissionsAdminPanelState();
}

class _PermissionsAdminPanelState extends State<PermissionsAdminPanel> {
  List<String> _emails = [];
    // Screen/navigation permissions
    final screenKeys = <String>[
      PermKeys.home,
      PermKeys.projects,
      PermKeys.persons,
      PermKeys.branches,
      PermKeys.attendance,
      PermKeys.leaves,
    ];
    // Task-level and field-level permissions (shown in grid)
    final taskKeys = <String>[
      PermKeys.tasksEdit,
      PermKeys.tasksDelete,
      PermKeys.taskEditTitle,
      PermKeys.taskEditNotes,
      PermKeys.taskEditStatus,
      PermKeys.taskEditPriority,
      PermKeys.taskEditProject,
      PermKeys.taskEditBranch,
      PermKeys.taskEditAssignee,
      PermKeys.taskEditDueDate,
    ];
  // Currently selected role being edited
  String selectedEmail = '';
  Set<String> allowed = {};
  bool loading = true;
  String? error;
  String _selectedAuthRole = 'employee';

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    setState(() { loading = true; error = null; });
    try {
      await _loadEmails();
      if (selectedEmail.isNotEmpty) {
        await _load();
      }
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  Future<void> _loadEmails() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('persons').orderBy('email').get();
      final fetched = snap.docs
          .map((d) => (d['email'] ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      setState(() {
        _emails = fetched;
        if (_emails.isNotEmpty && (selectedEmail.isEmpty || !_emails.contains(selectedEmail))) {
          selectedEmail = _emails.first;
        }
      });
    } catch (e) {
      // ignore errors; UI will show empty dropdown
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
  allowed = await PermissionsService.fetchAllowedKeysForEmail(selectedEmail);
    } catch (e) {
      error = 'Failed to load: $e';
    }
    setState(() { loading = false; });
  }

  Future<void> _save() async {
    setState(() { loading = true; error = null; });
    try {
  await FirebaseFirestore.instance.collection('userPerms').doc(selectedEmail).set({
        'allowed': allowed.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      error = 'Failed to save: $e';
    }
    setState(() { loading = false; });
    if (mounted && error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions saved')));
    }
  }

  Future<void> _setAuthRole() async {
    if (selectedEmail.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('setRoleByEmail');
      await callable.call({ 'email': selectedEmail, 'role': _selectedAuthRole });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set role=$_selectedAuthRole for $selectedEmail')),
        );
      }
    } catch (e) {
      error = 'Set role failed: $e';
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  Row(
                    children: [
                      const Text('Email:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _emails.contains(selectedEmail) && selectedEmail.isNotEmpty ? selectedEmail : null,
                        hint: const Text('Select email'),
                        items: _emails.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: _emails.isEmpty
                            ? null
                            : (v) {
                                if (v == null) return;
                                setState(() { selectedEmail = v; });
                                _load();
                              },
                      ),
                      const Spacer(),
                      // Auth role controls
                      const Text('Auth Role:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedAuthRole,
                        items: const [
                          DropdownMenuItem(value: 'employee', child: Text('Employee')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (v) => setState(() => _selectedAuthRole = v ?? 'employee'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedEmail.isNotEmpty ? _setAuthRole : null,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Set Role'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: selectedEmail.isNotEmpty ? _save : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        _moduleRow('Home',
                          viewKey: PermKeys.homeView,
                          editKey: PermKeys.homeEdit,
                          deleteKey: PermKeys.homeDelete,
                          alwaysOn: [PermKeys.home],
                        ),
                        _moduleRow('Projects',
                          viewKey: PermKeys.projectsView,
                          editKey: PermKeys.projectsEdit,
                          deleteKey: PermKeys.projectsDelete,
                        ),
                        _moduleRow('Persons',
                          viewKey: PermKeys.personsView,
                          editKey: PermKeys.personsEdit,
                          deleteKey: PermKeys.personsDelete,
                        ),
                        _moduleRow('Branches',
                          viewKey: PermKeys.branchesView,
                          editKey: PermKeys.branchesEdit,
                          deleteKey: PermKeys.branchesDelete,
                        ),
                        _moduleRow('Attendance',
                          viewKey: PermKeys.attendanceView,
                          editKey: PermKeys.attendanceEdit,
                          deleteKey: PermKeys.attendanceDelete,
                        ),
                        _moduleRow('Leaves',
                          viewKey: PermKeys.leavesView,
                          editKey: PermKeys.leavesEdit,
                          deleteKey: PermKeys.leavesDelete,
                        ),
                        const Divider(height: 24),
                        const Text('Task permissions'),
                        const SizedBox(height: 4),
                        // Tasks view/edit/delete
                        _moduleRow('Tasks',
                          viewKey: PermKeys.tasksView,
                          editKey: PermKeys.tasksEdit,
                          deleteKey: PermKeys.tasksDelete,
                        ),
                        const SizedBox(height: 8),
                        // Field-level toggles (simple list)
                        ...[
                          PermKeys.taskEditTitle,
                          PermKeys.taskEditNotes,
                          PermKeys.taskEditStatus,
                          PermKeys.taskEditPriority,
                          PermKeys.taskEditProject,
                          PermKeys.taskEditBranch,
                          PermKeys.taskEditAssignee,
                          PermKeys.taskEditDueDate,
                        ].map((k) => CheckboxListTile(
                              value: allowed.contains(k),
                              onChanged: (v) => setState(() => v == true ? allowed.add(k) : allowed.remove(k)),
                              title: Text(_labelFor(k)),
                            )),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  String _labelFor(String key) {
    switch (key) {
      case PermKeys.home:
        return 'Home';
      case PermKeys.projects:
        return 'Projects';
      case PermKeys.persons:
        return 'Persons';
      case PermKeys.branches:
        return 'Branches';
      case PermKeys.attendance:
        return 'Attendance';
      case PermKeys.leaves:
        return 'Leaves';
      case PermKeys.tasksEdit:
        return 'Tasks: Edit';
      case PermKeys.tasksDelete:
        return 'Tasks: Delete';
      case PermKeys.taskEditTitle:
        return 'Task field: Title';
      case PermKeys.taskEditNotes:
        return 'Task field: Notes';
      case PermKeys.taskEditStatus:
        return 'Task field: Status';
      case PermKeys.taskEditPriority:
        return 'Task field: Priority';
      case PermKeys.taskEditProject:
        return 'Task field: Project';
      case PermKeys.taskEditBranch:
        return 'Task field: Branch';
      case PermKeys.taskEditAssignee:
        return 'Task field: Assignee';
      case PermKeys.taskEditDueDate:
        return 'Task field: Due date';
      default:
        return key;
    }
  }

  Widget _moduleRow(String title, {required String viewKey, required String editKey, required String deleteKey, List<String> alwaysOn = const []}) {
    final bool view = allowed.contains(viewKey) || alwaysOn.isNotEmpty;
    final bool edit = allowed.contains(editKey);
    final bool del = allowed.contains(deleteKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Row(children: [
            Checkbox(
              value: view,
              onChanged: alwaysOn.isNotEmpty ? null : (v) => setState(() => v == true ? allowed.add(viewKey) : allowed.remove(viewKey)),
            ),
            const Text('View'),
            const SizedBox(width: 8),
            Checkbox(
              value: edit,
              onChanged: (v) => setState(() => v == true ? allowed.add(editKey) : allowed.remove(editKey)),
            ),
            const Text('Edit'),
            const SizedBox(width: 8),
            Checkbox(
              value: del,
              onChanged: (v) => setState(() => v == true ? allowed.add(deleteKey) : allowed.remove(deleteKey)),
            ),
            const Text('Delete'),
          ])
        ],
      ),
    );
  }
}
