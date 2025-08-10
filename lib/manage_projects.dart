import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'responsive.dart';

class ManageProjectsPage extends StatefulWidget {
  const ManageProjectsPage({super.key});

  @override
  State<ManageProjectsPage> createState() => _ManageProjectsPageState();
}

class _ManageProjectsPageState extends State<ManageProjectsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Projects'), backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: ManageProjectsPanel(),
      ),
    );
  }
}

class ManageProjectsPanel extends StatefulWidget {
  const ManageProjectsPanel({super.key});

  @override
  State<ManageProjectsPanel> createState() => _ManageProjectsPanelState();
}

class _ManageProjectsPanelState extends State<ManageProjectsPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String? _editingId; // null => add, non-null => update docId
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {'name': _nameCtrl.text.trim()};
    try {
      final col = FirebaseFirestore.instance.collection('projects');
      if (_editingId == null) {
        await col.add(data);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project added')));
      } else {
        await col.doc(_editingId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project updated')));
      }
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _startEdit(String id, String name) {
    setState(() {
      _editingId = id;
      _nameCtrl.text = name;
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
    });
  }

  Future<void> _delete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('projects').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);
    return Column(
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Form(
              key: _formKey,
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(labelText: 'Project Name', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter project name' : null,
                        ),
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
                            OutlinedButton(onPressed: _clearForm, child: Text('Cancel')),
                          ],
                        ]),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(labelText: 'Project Name', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter project name' : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: Icon(_editingId == null ? Icons.add : Icons.save),
                          label: Text(_editingId == null ? 'Add' : 'Update'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
                        ),
                        if (_editingId != null) ...[
                          SizedBox(width: 8),
                          OutlinedButton(onPressed: _clearForm, child: Text('Cancel')),
                        ],
                      ],
                    ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('projects').orderBy('name').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Center(child: Text('No projects'));
              return ListView.separated(
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString();
                  return ListTile(
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Wrap(spacing: 8, children: [
                      IconButton(icon: Icon(Icons.edit, color: Colors.orange[700]), onPressed: () => _startEdit(d.id, name)),
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
