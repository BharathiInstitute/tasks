// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'permissions.dart';

// Dialog to create or edit a task. Pass existing map to edit.
Future<void> showAddTaskDialog(
  BuildContext context, {
  Map<String, dynamic>? existing,
  required Set<String> allowed,
  bool enforceSelf = false, // when true (My Tasks) force branch/assignee to current user
  String? selfName,
  String? selfBranch,
  String? selfEmail,
}) async {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final dueDateTextController = TextEditingController();
  String? selectedProject;
  String? selectedBranch;
  String? selectedPerson;
  String selectedPriority = 'Medium';
  String selectedStatus = 'Pending';
  DateTime? selectedDueDate;
  List<String> projectOptions = [];
  List<String> branchOptions = [];
  List<String> personOptions = [];
  // New condensed option sets
  final List<String> priorityOptions = ['Urgent', 'Medium', 'Low'];
  final List<String> statusOptions = ['Working', 'Pending', 'Completed'];

  final projectSnap = await FirebaseFirestore.instance.collection('projects').get();
  projectOptions = projectSnap.docs.map((d) => (d.data()['name'] ?? '') as String).where((e) => e.isNotEmpty).toList();
  if (existing != null && projectOptions.contains(existing['project'])) {
    selectedProject = existing['project'];
  } else if (projectOptions.isNotEmpty) {
    selectedProject = projectOptions.first;
  }

  final branchSnap = await FirebaseFirestore.instance.collection('branches').get();
  branchOptions = branchSnap.docs.map((d) => (d.data()['name'] ?? '') as String).where((e) => e.isNotEmpty).toList();
  if (enforceSelf) {
    if (selfBranch != null && selfBranch.isNotEmpty) {
      selectedBranch = selfBranch;
    } else if (selfEmail != null && selfEmail.isNotEmpty) {
      // resolve branch by person email if not provided
      try {
        final persons = await FirebaseFirestore.instance.collection('persons').where('email', isEqualTo: selfEmail).limit(1).get();
        if (persons.docs.isNotEmpty) {
          final pdata = persons.docs.first.data();
            final branchId = (pdata['branchId'] ?? '').toString();
            if (branchId.isNotEmpty) {
              final bdoc = await FirebaseFirestore.instance.collection('branches').doc(branchId).get();
              final bname = (bdoc.data()?['name'] ?? '').toString();
              if (bname.isNotEmpty) selectedBranch = bname;
            } else {
              // some schemas might store branch directly by name
              final bname2 = (pdata['branch'] ?? '').toString();
              if (bname2.isNotEmpty) selectedBranch = bname2;
            }
        }
      } catch (_) {}
    }
  } else if (existing != null && branchOptions.contains(existing['branch'])) {
    selectedBranch = existing['branch'];
  } else if (branchOptions.isNotEmpty) {
    selectedBranch = branchOptions.first;
  }

  Future<void> fetchPersonsForBranch(String branch) async {
    if (enforceSelf) {
      // We'll just use selfName; skip loading full list.
      selectedPerson = selfName;
      personOptions = selfName != null && selfName.isNotEmpty ? [selfName] : [];
      return;
    }
    personOptions = [];
    try {
      // 1. Query by branch name (legacy schema)
      final byName = await FirebaseFirestore.instance.collection('persons').where('branch', isEqualTo: branch).get();
      for (final d in byName.docs) {
        final n = (d.data()['name'] ?? '') as String; if (n.isNotEmpty && !personOptions.contains(n)) personOptions.add(n);
      }
      // 2. Resolve branchId from branches collection then query persons by branchId (newer schema)
      final branchDoc = await FirebaseFirestore.instance.collection('branches').where('name', isEqualTo: branch).limit(1).get();
      if (branchDoc.docs.isNotEmpty) {
        final bId = branchDoc.docs.first.id;
        final byId = await FirebaseFirestore.instance.collection('persons').where('branchId', isEqualTo: bId).get();
        for (final d in byId.docs) {
          final n = (d.data()['name'] ?? '') as String; if (n.isNotEmpty && !personOptions.contains(n)) personOptions.add(n);
        }
      }
    } catch (_) {}
    // 3. Pick selectedPerson
    if (existing != null && personOptions.contains(existing['assignTo'])) {
      selectedPerson = existing['assignTo'];
    } else if (personOptions.isNotEmpty) {
      selectedPerson = personOptions.first;
    } else {
      // fallback to self if available
      if ((selfName ?? '').isNotEmpty) selectedPerson = selfName;
    }
  }
  if (selectedBranch != null) await fetchPersonsForBranch(selectedBranch);

  if (existing != null) {
    nameController.text = (existing['name'] ?? '').toString();
    notesController.text = (existing['notes'] ?? '').toString();
    final exPriority = (existing['priority'] ?? '').toString();
    if (exPriority.isNotEmpty) {
      final p = exPriority.toLowerCase();
      if (p == 'high') {
        selectedPriority = 'Urgent';
      } else if (p == 'medium') {
        selectedPriority = 'Medium';
      } else if (p == 'low') {
        selectedPriority = 'Low';
      } else if (p == 'urgent') {
        selectedPriority = 'Urgent';
      }
    }
    final exStatus = (existing['status'] ?? '').toString();
    if (exStatus.isNotEmpty) {
      final s = exStatus.toLowerCase();
      if (s.contains('work') || s.contains('progress') || s.contains('start')) {
        selectedStatus = 'Working';
      } else if (s.contains('complete') || s.contains('done')) {
        selectedStatus = 'Completed';
      } else if (s.contains('pending') || s.contains('todo')) {
        selectedStatus = 'Pending';
      }
    }
    final due = existing['dueDate'];
    if (due is int) {
      selectedDueDate = DateTime.fromMillisecondsSinceEpoch(due);
  dueDateTextController.text = '${selectedDueDate.day.toString().padLeft(2,'0')}/${selectedDueDate.month.toString().padLeft(2,'0')}/${selectedDueDate.year}';
    }
  }

  await showDialog(
    context: context,
    builder: (ctx) {
  bool saving = false; // local saving state for progress indicator
  return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
            title: Row(
              children: [
                Expanded(child: Text(existing == null ? 'New Task' : 'Edit Task', style: const TextStyle(fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 720,
                child: Builder(builder: (context) {
                  // Project selection open to every user (permission check removed)
                  final canEditBranch = enforceSelf ? false : allowed.contains(PermKeys.taskEditBranch);
                  final canEditAssignee = enforceSelf ? false : allowed.contains(PermKeys.taskEditAssignee);
                  final canEditTitle = allowed.contains(PermKeys.taskEditTitle);
                  final canEditNotes = allowed.contains(PermKeys.taskEditNotes);
                  final canEditDue = allowed.contains(PermKeys.taskEditDueDate);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!enforceSelf && (personOptions.isEmpty))
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            border: Border.all(color: Colors.amber.shade700),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.black87, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                                    children: <InlineSpan>[
                                      const TextSpan(text: 'No persons found for this Section. '),
                                      TextSpan(
                                        text: 'Add a person',
                                        style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () async {
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Go to Persons to add members to this Section.')),
                                            );
                                          },
                                      ),
                                      const TextSpan(text: ' or pick another Section.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedProject,
                            decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder()),
                            items: projectOptions.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                            onChanged: (v) => setState(() => selectedProject = v),
                            disabledHint: Text(selectedProject ?? ''),
                          ),
                        ),
                        if (!enforceSelf) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedBranch,
                              decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                              items: branchOptions.map((b) => DropdownMenuItem<String>(value: b, child: Text(b))).toList(),
                              onChanged: canEditBranch
                                  ? (v) async {
                                      setState(() => selectedBranch = v);
                                      if (v != null) {
                                        await fetchPersonsForBranch(v);
                                        setState(() {});
                                      }
                                    }
                                  : null,
                              disabledHint: Text(selectedBranch ?? ''),
                            ),
                          ),
                        ],
                      ]),
                    const SizedBox(height: 12),
                    Column(children:[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Task',
                          hintText: 'e.g., Create Firestore indexes',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: !canEditTitle,
                      ),
                      if (!enforceSelf) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedPerson,
                          decoration: const InputDecoration(labelText: 'Assignee', border: OutlineInputBorder()),
                          items: personOptions.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                          onChanged: canEditAssignee ? (v) => setState(() => selectedPerson = v) : null,
                          disabledHint: Text(selectedPerson ?? ''),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional details',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      readOnly: !canEditNotes,
                    ),
                    const SizedBox(height: 12),
                    // Status & (optionally) Priority/Due row
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                          items: statusOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                          onChanged: (v) => setState(() => selectedStatus = v ?? selectedStatus),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPriority,
                          decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                          items: priorityOptions.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() => selectedPriority = v ?? selectedPriority),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: dueDateTextController,
                          readOnly: !canEditDue,
                          decoration: InputDecoration(
                            labelText: 'Due Date',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: !canEditDue
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDueDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          selectedDueDate = picked;
                                          dueDateTextController.text = '${picked.day.toString().padLeft(2,'0')}/${picked.month.toString().padLeft(2,'0')}/${picked.year}';
                                        });
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: saving ? null : () async {
                          final name = nameController.text.trim();
                          final branch = enforceSelf ? (selfBranch?.isNotEmpty == true ? selfBranch! : (selectedBranch ?? '')) : (selectedBranch ?? '');
                          final assignTo = enforceSelf ? (selfName ?? selectedPerson ?? '') : (selectedPerson ?? '');
                          final notes = notesController.text.trim();
                          if (name.isNotEmpty && branch.isNotEmpty && assignTo.isNotEmpty && selectedProject != null) {
                            setState(()=> saving = true);
                            if (existing == null) {
                              final ref = FirebaseFirestore.instance.collection('tasks').doc();
                              final uid = FirebaseAuth.instance.currentUser?.uid;
                              await ref.set({
                                'id': ref.id,
                                'project': selectedProject,
                                'branch': branch,
                                'name': name,
                                'assignTo': assignTo,
                                'assigneeEmail': selfEmail ?? '',
                                'assigneeUid': uid ?? '',
                                'createdBy': uid ?? '',
                                'priority': selectedPriority,
                                'status': selectedStatus,
                                'dueDate': selectedDueDate?.millisecondsSinceEpoch,
                                'notes': notes,
                                'createdAt': DateTime.now().millisecondsSinceEpoch,
                              });
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task added successfully!')));
                            } else {
                              final id = (existing['id'] ?? '').toString();
                              if (id.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot update: missing task id')));
                                setState(()=> saving=false);
                                return;
                              }
                              final uid = FirebaseAuth.instance.currentUser?.uid;
                              await FirebaseFirestore.instance.collection('tasks').doc(id).set({
                                'project': selectedProject,
                                'branch': branch,
                                'name': name,
                                'assignTo': assignTo,
                                'assigneeEmail': selfEmail ?? '',
                                'assigneeUid': uid ?? '',
                                'priority': selectedPriority,
                                'status': selectedStatus,
                                'dueDate': selectedDueDate?.millisecondsSinceEpoch,
                                'notes': notes,
                                'updatedAt': DateTime.now().millisecondsSinceEpoch,
                              }, SetOptions(merge: true));
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated successfully!')));
                            }
                          } else {
                            if (enforceSelf && (branch.isEmpty || assignTo.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your profile is missing branch or name. Contact admin.')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all required fields')));
                            }
              setState(()=> saving=false);
                          }
                        },
            child: saving
              ? const SizedBox(width:18,height:18, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white))
              : Text(existing == null ? 'Create Task' : 'Save Changes'),
                      ),
                    ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      );
    },
  );
}
