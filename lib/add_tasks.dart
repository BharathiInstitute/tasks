import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Top-level dialog function to add a task as a popup
Future<void> showAddTaskDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final dueDateTextController = TextEditingController();
  String? selectedProject;
  String? selectedBranch;
  String? selectedPerson;
  String selectedStatus = 'Todo';
  String selectedPriority = 'Medium';
  DateTime? selectedDueDate;
  List<String> projectOptions = [];
  List<String> branchOptions = [];
  List<String> personOptions = [];
  final List<String> statusOptions = ['Todo', 'In Progress', 'Blocked', 'Done'];
  final List<String> priorityOptions = ['Low', 'Medium', 'High', 'Urgent'];

  // Load initial dropdown data
  final projectSnap = await FirebaseFirestore.instance.collection('projects').get();
  projectOptions = projectSnap.docs.map((d) => (d.data()['name'] ?? '') as String).where((e) => e.isNotEmpty).toList();
  if (projectOptions.isNotEmpty) selectedProject = projectOptions.first;

  final branchSnap = await FirebaseFirestore.instance.collection('branches').get();
  branchOptions = branchSnap.docs.map((d) => (d.data()['name'] ?? '') as String).where((e) => e.isNotEmpty).toList();
  if (branchOptions.isNotEmpty) selectedBranch = branchOptions.first;

  Future<void> fetchPersonsForBranch(String branch) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('persons')
        .where('branch', isEqualTo: branch)
        .get();
    personOptions = snapshot.docs.map((d) => (d.data()['name'] ?? '') as String).where((e) => e.isNotEmpty).toList();
    if (personOptions.isNotEmpty) selectedPerson = personOptions.first;
  }
  if (selectedBranch != null) await fetchPersonsForBranch(selectedBranch);

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            titlePadding: EdgeInsets.fromLTRB(24, 20, 12, 0),
            title: Row(
              children: [
                Expanded(child: Text('New Task', style: TextStyle(fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 720,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Project | Section (Branch)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedProject,
                            decoration: InputDecoration(labelText: 'Project', border: OutlineInputBorder()),
                            items: projectOptions
                                .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => selectedProject = v),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedBranch,
                            decoration: InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                            items: branchOptions
                                .map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                                .toList(),
                            onChanged: (v) async {
                              setState(() => selectedBranch = v);
                              if (v != null) {
                                await fetchPersonsForBranch(v);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Row 2: Title | Assignee
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              hintText: 'e.g., Create Firestore indexes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPerson,
                            decoration: InputDecoration(labelText: 'Assignee', border: OutlineInputBorder()),
                            items: personOptions
                                .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => selectedPerson = v),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Description (Notes)
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional details',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 12),
                    // Row 3: Priority | Status | Due Date
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPriority,
                            decoration: InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                            items: priorityOptions
                                .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => selectedPriority = v ?? selectedPriority),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedStatus,
                            decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                            items: statusOptions
                                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => selectedStatus = v ?? selectedStatus),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: dueDateTextController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Due Date',
                              border: OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.calendar_today),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDueDate ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      selectedDueDate = picked;
                                      dueDateTextController.text =
                                          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final branch = selectedBranch ?? '';
                          final assignTo = selectedPerson ?? '';
                          final notes = notesController.text.trim();
                          if (name.isNotEmpty && branch.isNotEmpty && assignTo.isNotEmpty && selectedProject != null) {
                            final ref = FirebaseFirestore.instance.collection('tasks').doc();
                            await ref.set({
                              'id': ref.id,
                              'project': selectedProject,
                              'branch': branch,
                              'name': name,
                              'assignTo': assignTo,
                              'status': selectedStatus,
                              'priority': selectedPriority,
                              'dueDate': selectedDueDate?.millisecondsSinceEpoch,
                              'notes': notes,
                              'createdAt': DateTime.now().millisecondsSinceEpoch,
                            });
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task added successfully!')));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill in all required fields')));
                          }
                        },
                        child: Text('Create Task'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
