import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'responsive.dart';

class ManagePersonsPage extends StatefulWidget {
  const ManagePersonsPage({super.key});

  @override
  State<ManagePersonsPage> createState() => _ManagePersonsPageState();
}

class _ManagePersonsPageState extends State<ManagePersonsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Persons'), backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: ManagePersonsPanel(),
      ),
    );
  }
}

class ManagePersonsPanel extends StatefulWidget {
  const ManagePersonsPanel({super.key});

  @override
  State<ManagePersonsPanel> createState() => _ManagePersonsPanelState();
}

class _ManagePersonsPanelState extends State<ManagePersonsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _branch;
  String? _role = 'Other';
  String? _editingId;
  bool _saving = false;

  List<String> _roles = [];
  List<String> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  _loadRoles();
  }

  Future<void> _loadBranches() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('branches').get();
      setState(() {
        _branches = snap.docs.map((d) => (d['name'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
        if (_branches.isNotEmpty) _branch ??= _branches.first;
      });
    } catch (_) {}
  }

  Future<void> _loadRoles() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('roles').orderBy('name').get();
      setState(() {
        _roles = snap.docs
            .map((d) => (d['name'] ?? '').toString())
            .where((e) => e.isNotEmpty)
            .toList();
        if (_roles.isNotEmpty && (_role == null || !_roles.contains(_role))) {
          _role = _roles.first;
        }
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_branch == null || _role == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Select branch and role')));
      return;
    }
    setState(() => _saving = true);
    final col = FirebaseFirestore.instance.collection('persons');
    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'branch': _branch,
      'role': _role,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      // Create or update Firebase Auth user using a callable function (admin privileges required)
      final email = _emailCtrl.text.trim();
  final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final callable = functions.httpsCallable('adminUpsertUser');
      final payload = {
        'email': email,
        'displayName': _nameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
      };
      final pw = _passwordCtrl.text;
      if (pw.isNotEmpty) payload['password'] = pw; // optional on update
      if (email.isNotEmpty) {
        await callable.call(payload);
      }
      if (_editingId == null) {
        await col.add({...data, 'createdAt': DateTime.now().millisecondsSinceEpoch});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Person added')));
      } else {
        await col.doc(_editingId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Person updated')));
      }
      _clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startEdit(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingId = doc.id;
      _nameCtrl.text = (data['name'] ?? '').toString();
      _emailCtrl.text = (data['email'] ?? '').toString();
      _phoneCtrl.text = (data['phone'] ?? '').toString();
      _branch = (data['branch'] ?? '').toString();
      _role = (data['role'] ?? 'Other').toString();
    });
  }

  void _clear() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
  _passwordCtrl.clear();
      // keep last selected branch/role
    });
  }

  Future<void> _delete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('persons').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Person deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    final roleItems = <DropdownMenuItem<String>>[
      if (_role != null && !_roles.contains(_role))
        DropdownMenuItem<String>(value: _role, child: Text('${_role!} (missing)')),
      ..._roles.map((r) => DropdownMenuItem<String>(value: r, child: Text(r))).toList(),
    ];
    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!compact) ...[
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _role,
                          decoration: InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                          items: roleItems,
                          onChanged: _roles.isEmpty ? null : (v) => setState(() => _role = v),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _branch,
                          decoration: InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
                          items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (v) => setState(() => _branch = v),
                        ),
                      ),
                    ]),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter email';
                            if (!v.contains('@') || !v.contains('.')) return 'Enter valid email';
                            return null;
                          },
                        ),
                      ),
                    ]),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.trim().length < 10 ? 'Enter valid phone' : null,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _passwordCtrl,
                          decoration: InputDecoration(labelText: 'Password (Auth only, not stored)', border: OutlineInputBorder()),
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          validator: (v) {
                            if (_editingId == null) {
                              // On create require a password
                              if (v == null || v.length < 6) return 'Min 6 chars';
                            }
                            return null;
                          },
                        ),
                      ),
                    ]),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                      items: roleItems,
                      onChanged: _roles.isEmpty ? null : (v) => setState(() => _role = v),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _branch,
                      decoration: InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
                      items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setState(() => _branch = v),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter email';
                        if (!v.contains('@') || !v.contains('.')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.trim().length < 10 ? 'Enter valid phone' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(labelText: 'Password (Auth only, not stored)', border: OutlineInputBorder()),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      validator: (v) {
                        if (_editingId == null) {
                          if (v == null || v.length < 6) return 'Min 6 chars';
                        }
                        return null;
                      },
                    ),
                  ],
                  SizedBox(height: 12),
                  Row(children: [
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: Icon(_editingId == null ? Icons.add : Icons.save),
                      label: Text(_editingId == null ? 'Add' : 'Update'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
                    ),
                    if (_editingId != null) ...[
                      SizedBox(width: 8),
                      OutlinedButton(onPressed: _clear, child: Text('Cancel')),
                    ],
                  ])
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('persons').orderBy('name').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Center(child: Text('No persons'));
              return ListView.separated(
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString();
                  final email = (data['email'] ?? '').toString();
                  final phone = (data['phone'] ?? '').toString();
                  final branch = (data['branch'] ?? '').toString();
                  final role = (data['role'] ?? '').toString();
                  return ListTile(
                    leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$email • $phone • $branch • $role'),
                    trailing: Wrap(spacing: 8, children: [
                      IconButton(icon: Icon(Icons.edit, color: Colors.orange[700]), onPressed: () => _startEdit(d)),
                      IconButton(icon: Icon(Icons.delete, color: Colors.red[700]), onPressed: () => _delete(d.id)),
                    ]),
                  );
                },
                separatorBuilder: (_, __) => SizedBox(height: 6),
                itemCount: docs.length,
              );
            },
          ),
        )
      ],
    );
  }
}
