import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'permissions.dart';

class PermissionsAdminPanel extends StatefulWidget {
  const PermissionsAdminPanel({super.key});

  @override
  State<PermissionsAdminPanel> createState() => _PermissionsAdminPanelState();
}

class _PermissionsAdminPanelState extends State<PermissionsAdminPanel> {
  // Cached selectable user emails
  List<String> _emails = [];
  // Current single admin email (enforced in UI)
  String? _currentAdminEmail;
  // Currently selected role being edited
  String selectedEmail = '';
  Set<String> allowed = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    setState(() { loading = true; error = null; });
    try {
      await _loadEmails();
      await _loadCurrentAdmin();
      if (selectedEmail.isNotEmpty) {
        await _load();
      }
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  Future<void> _loadCurrentAdmin() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('roles').doc('adminConfig').get();
      final data = doc.data();
      final e = (data?['adminEmail'] ?? '').toString().trim().toLowerCase();
      setState(() {
        _currentAdminEmail = e.isEmpty ? null : e;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadEmails() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('persons').orderBy('email').get();
      final fetched = snap.docs
        .map((d) => (d['email'] ?? '').toString().trim().toLowerCase())
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
      final key = selectedEmail.trim().toLowerCase();
      final snap = await FirebaseFirestore.instance.collection('userPerms').doc(key).get();
      final data = snap.data();
      if (data != null && data['allowed'] is List) {
        allowed = List<String>.from(data['allowed']).toSet();
      } else {
        allowed = {};
      }
    } catch (e) {
      error = 'Failed to load: $e';
    }
    setState(() { loading = false; });
  }

  Future<void> _save() async {
    setState(() { loading = true; error = null; });
    try {
  final key = selectedEmail.trim().toLowerCase();
  await FirebaseFirestore.instance.collection('userPerms').doc(key).set({
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

  Future<void> _makeAdmin() async {
    if (selectedEmail.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('setRoleByEmail');
      await callable.call({ 'email': selectedEmail.trim().toLowerCase(), 'role': 'admin' });
      // persist current admin email for single-admin enforcement
      await FirebaseFirestore.instance.collection('roles').doc('adminConfig').set({
        'adminEmail': selectedEmail.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _currentAdminEmail = selectedEmail.trim().toLowerCase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin role granted to ${selectedEmail.trim().toLowerCase()}')),
        );
      }
    } catch (e) {
      setState(() { error = 'Failed to set admin: $e'; });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  Future<void> _transferAdmin() async {
    if (selectedEmail.isEmpty) return;
    final newAdmin = selectedEmail.trim().toLowerCase();
    final oldAdmin = (_currentAdminEmail ?? '').trim().toLowerCase();
    if (newAdmin == oldAdmin) return;
    setState(() { loading = true; error = null; });
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('setRoleByEmail');
      if (oldAdmin.isNotEmpty) {
        await callable.call({ 'email': oldAdmin, 'role': 'employee' });
      }
      await callable.call({ 'email': newAdmin, 'role': 'admin' });
      await FirebaseFirestore.instance.collection('roles').doc('adminConfig').set({
        'adminEmail': newAdmin,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _currentAdminEmail = newAdmin;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transferred admin to $newAdmin')),
        );
      }
    } catch (e) {
      setState(() { error = 'Failed to transfer admin: $e'; });
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
                                setState(() { selectedEmail = v.toLowerCase(); });
                                _load();
                              },
                      ),
                      const Spacer(),
                      if ((_currentAdminEmail ?? '').isEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: selectedEmail.isNotEmpty ? _makeAdmin : null,
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const Text('Make Admin'),
                        ),
                      ] else ...[
                        // Show current admin and allow transfer
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('Current admin: ${_currentAdminEmail!}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                        OutlinedButton.icon(
                          onPressed: (selectedEmail.isNotEmpty && selectedEmail.toLowerCase() != _currentAdminEmail)
                              ? _transferAdmin
                              : null,
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Transfer Admin'),
                        ),
                      ],
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: selectedEmail.isNotEmpty ? _save : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Admins list (single-admin view)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.black12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Admins', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          if ((_currentAdminEmail ?? '').isEmpty)
                            const Text('No admin set'),
                          if ((_currentAdminEmail ?? '').isNotEmpty)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.shield_outlined),
                              title: Text(_currentAdminEmail!),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Permissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        // Removed Home permissions row (user request) – home access assumed baseline.
                        _moduleRow('Projects',
                          viewKey: PermKeys.projectsView,
                          addKey: PermKeys.projectsAdd,
                          editKey: PermKeys.projectsEdit,
                          deleteKey: PermKeys.projectsDelete,
                        ),
                        _moduleRow('Persons',
                          viewKey: PermKeys.personsView,
                          addKey: PermKeys.personsAdd,
                          editKey: PermKeys.personsEdit,
                          deleteKey: PermKeys.personsDelete,
                        ),
                        _moduleRow('Branches',
                          viewKey: PermKeys.branchesView,
                          addKey: PermKeys.branchesAdd,
                          editKey: PermKeys.branchesEdit,
                          deleteKey: PermKeys.branchesDelete,
                        ),
                        // Leaves permissions & approve toggle removed per request
                        // Attendance permissions remain implicit
                        // Roles module row removed
                        const Divider(height: 24),
                        const Text('My Tasks'),
                        const SizedBox(height: 4),
                        // Custom tasks row without Edit checkbox
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Expanded(child: Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w600))),
                              Row(children: [
                                Checkbox(
                                  value: allowed.contains(PermKeys.tasksView),
                                  onChanged: (v) => setState(() => v == true ? allowed.add(PermKeys.tasksView) : allowed.remove(PermKeys.tasksView)),
                                ),
                                const Text('View'),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: allowed.contains(PermKeys.tasksAdd),
                                  onChanged: (v) => setState(() => v == true ? allowed.add(PermKeys.tasksAdd) : allowed.remove(PermKeys.tasksAdd)),
                                ),
                                const Text('Add'),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: allowed.contains(PermKeys.tasksDelete),
                                  onChanged: (v) => setState(() => v == true ? allowed.add(PermKeys.tasksDelete) : allowed.remove(PermKeys.tasksDelete)),
                                ),
                                const Text('Delete'),
                              ])
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Field-level permissions (order: Project, Branch, Assignee, Task, Notes, Priority, Due date)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical:4.0),
                              child: Row(children:[
                                const Expanded(child: Text('Filters', style: TextStyle(fontWeight: FontWeight.w600))),
                                Checkbox(
                                  value: allowed.contains(PermKeys.branchFilterView),
                                  onChanged: (v)=> setState(()=> v==true ? allowed.add(PermKeys.branchFilterView) : allowed.remove(PermKeys.branchFilterView)),
                                ),
                                const Text('Branch Filter'),
                              ]),
                            ),
                            _fieldToggle('Project', PermKeys.taskEditProject),
                            _fieldToggle('Branch', PermKeys.taskEditBranch),
                            _fieldToggle('Assignee', PermKeys.taskEditAssignee),
                            _fieldToggle('Task', PermKeys.taskEditTitle),
                            _fieldToggle('Notes', PermKeys.taskEditNotes),
                            _fieldToggle('Priority', PermKeys.taskEditPriority),
                            _fieldToggle('Due date', PermKeys.taskEditDueDate),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  // _labelFor removed along with field-level task permission toggles

  Widget _moduleRow(String title, {required String viewKey, String? addKey, required String editKey, required String deleteKey, List<String> alwaysOn = const []}) {
    final bool view = allowed.contains(viewKey) || alwaysOn.isNotEmpty;
    final bool add = addKey != null && allowed.contains(addKey);
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
            if (addKey != null) ...[
              Checkbox(
                value: add,
                onChanged: (v) => setState(() => v == true ? allowed.add(addKey) : allowed.remove(addKey)),
              ),
              const Text('Add'),
              const SizedBox(width: 8),
            ],
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

  Widget _fieldToggle(String label, String key) {
    final enabled = allowed.contains(key);
    return InkWell(
      onTap: () => setState(() => enabled ? allowed.remove(key) : allowed.add(key)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: enabled,
                onChanged: (v) => setState(() => v == true ? allowed.add(key) : allowed.remove(key)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
