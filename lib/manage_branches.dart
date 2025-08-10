import 'package:cloud_firestore/cloud_firestore.dart';
import 'responsive.dart';
import 'package:flutter/material.dart';

class ManageBranchesPage extends StatefulWidget {
  const ManageBranchesPage({super.key});

  @override
  State<ManageBranchesPage> createState() => _ManageBranchesPageState();
}

class _ManageBranchesPageState extends State<ManageBranchesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Branches'), backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: ManageBranchesPanel(),
      ),
    );
  }
}

class ManageBranchesPanel extends StatefulWidget {
  const ManageBranchesPanel({super.key});

  @override
  State<ManageBranchesPanel> createState() => _ManageBranchesPanelState();
}

class _ManageBranchesPanelState extends State<ManageBranchesPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String? _editingId;
  bool _saving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final col = FirebaseFirestore.instance.collection('branches');
      final data = {'name': _nameCtrl.text.trim()};
      if (_editingId == null) {
        await col.add(data);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Branch added')));
      } else {
        await col.doc(_editingId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Branch updated')));
      }
      _clear();
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

  void _clear() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
    });
  }

  Future<void> _delete(String id) async {
    try {
      await FirebaseFirestore.instance.collection('branches').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Branch deleted')));
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
                          decoration: InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter branch name' : null,
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _submit,
                              icon: Icon(_editingId == null ? Icons.add : Icons.save),
                              label: Text(_editingId == null ? 'Add' : 'Update'),
                            ),
                            if (_editingId != null) ...[
                              SizedBox(width: 8),
                              OutlinedButton(onPressed: _clear, child: Text('Cancel')),
                            ]
                          ],
                        )
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter branch name' : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: Icon(_editingId == null ? Icons.add : Icons.save),
                          label: Text(_editingId == null ? 'Add' : 'Update'),
                        ),
                        if (_editingId != null) ...[
                          SizedBox(width: 8),
                          OutlinedButton(onPressed: _clear, child: Text('Cancel')),
                        ]
                      ],
                    ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('branches').orderBy('name').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return Center(child: Text('No branches'));
              return ListView.separated(
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final name = (d['name'] ?? '').toString();
                  return ListTile(
                    title: Text(name),
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
