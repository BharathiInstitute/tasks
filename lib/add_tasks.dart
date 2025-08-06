import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:math';
import 'view_items_screen.dart';

class AddTaskScreen extends StatefulWidget {
  AddTaskScreen({super.key});

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final nameController = TextEditingController();
  String? selectedPerson;
  List<String> personOptions = [];
  final notesController = TextEditingController();

  String selectedStatus = 'Pending';
  String? selectedBranch;
  DateTime? selectedDate;
  DateTime? selectedDueDate;

  final List<String> statusOptions = [ 'Started','Pending','In Progress', 'Completed', 'On Hold'];
  List<String> branchOptions = [];

  @override
  void initState() {
    super.initState();
    fetchBranches();
  }

  void fetchPersonsForBranch(String branch) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('persons')
        .where('branch', isEqualTo: branch)
        .get();
    List<String> persons = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        persons.add(data['name']);
      }
    }
    setState(() {
      personOptions = persons;
      selectedPerson = personOptions.isNotEmpty ? personOptions.first : null;
    });
  }

  void fetchBranches() async {
    final snapshot = await FirebaseFirestore.instance.collection('branches').get();
    List<String> branches = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        branches.add(data['name']);
      }
    }
    setState(() {
      branchOptions = branches;
      if (branchOptions.isNotEmpty) {
        selectedBranch = branchOptions.first;
        fetchPersonsForBranch(selectedBranch!);
      }
    });
  }

  void addItem() async {
    final name = nameController.text.trim();
    final branch = selectedBranch ?? '';
    final assignTo = selectedPerson ?? '';
    final notes = notesController.text.trim();

    if (name.isNotEmpty && branch.isNotEmpty && assignTo.isNotEmpty) {
      final ref = FirebaseFirestore.instance.collection('tasks').doc();
      await ref.set({
        'id': ref.id,
        'branch': branch,
        'name': name,
        'assignTo': assignTo,
        'status': selectedStatus,
        'date': selectedDate?.millisecondsSinceEpoch,
        'dueDate': selectedDueDate?.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      nameController.clear();
      notesController.clear();
      setState(() {
        selectedStatus = 'Pending';
        selectedBranch = branchOptions.isNotEmpty ? branchOptions.first : null;
        selectedDate = null;
        selectedDueDate = null;
        if (selectedBranch != null) {
          fetchPersonsForBranch(selectedBranch!);
        } else {
          personOptions = [];
          selectedPerson = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task added successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ViewItemsScreen()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ...existing code...
              DropdownButtonFormField<String>(
                value: selectedBranch,
                decoration: InputDecoration(
                  labelText: 'Branch *',
                  border: OutlineInputBorder(),
                ),
                items: branchOptions.map((String branch) {
                  return DropdownMenuItem<String>(
                    value: branch,
                    child: Text(branch),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedBranch = newValue!;
                  });
                  if (newValue != null) {
                    fetchPersonsForBranch(newValue);
                  }
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPerson,
                decoration: InputDecoration(
                  labelText: 'Assign To *',
                  border: OutlineInputBorder(),
                ),
                items: personOptions.map((String person) {
                  return DropdownMenuItem<String>(
                    value: person,
                    child: Text(person),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedPerson = newValue;
                  });
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Task Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: statusOptions.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedStatus = newValue!;
                  });
                },
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Date: ${selectedDate != null ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}" : "Not selected"}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && picked != selectedDate) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey),
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Due Date: ${selectedDueDate != null ? "${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}" : "Not selected"}'),
                trailing: Icon(Icons.event),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null && picked != selectedDueDate) {
                    setState(() {
                      selectedDueDate = picked;
                    });
                  }
                },
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: addItem,
                  child: Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
