import 'add_persons.dart';
import 'add_tasks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_branch.dart';
import 'package:flutter/material.dart';
import 'show.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedBranch;
  String? selectedPerson;
  String? selectedStatus;
  DateTime? startDate;
  DateTime? endDate;
  List<String> allBranches = [];
  List<String> allPersons = [];

  @override
  void initState() {
    super.initState();
    fetchBranchesAndPersons();
  }

  void fetchBranchesAndPersons() async {
    final branchSnap = await _firestore.collection('branches').get();
    final personSnap = await _firestore.collection('persons').get();
    setState(() {
      allBranches = branchSnap.docs.map((doc) => (doc.data()['name'] ?? '') as String).where((e) => e != '').toList();
      allPersons = personSnap.docs.map((doc) => (doc.data()['name'] ?? '') as String).where((e) => e != '').toList();
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks App'),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            tooltip: 'Show',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ShowMenuScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.add, color: Colors.white),
            tooltip: 'Add',
            onSelected: (String value) {
              if (value == 'person') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddPersonScreen()),
                );
              } else if (value == 'branch') {
                showDialog(
                  context: context,
                  builder: (context) => AddBranchDialog(
                    branchOptions: const [],
                    firestore: _firestore,
                    onBranchAdded: () {},
                  ),
                );
              } else if (value == 'task') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddTaskScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'person',
                child: ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Add Person'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'branch',
                child: ListTile(
                  leading: Icon(Icons.add_business),
                  title: Text('Add Branch'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'task',
                child: ListTile(
                  leading: Icon(Icons.add_task),
                  title: Text('Add Task'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tasks').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No tasks found.'));
          }
          final tasks = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

          // Collect unique filter values
          final branches = allBranches;
          final persons = allPersons;
          final statuses = [
            'Pending',
            'Started',
            'In Progress',
            'Completed',
            'On Hold',
          ];

          // Filter logic
          List<Map<String, dynamic>> filtered = tasks.where((task) {
            final branchMatch = selectedBranch == null || task['branch'] == selectedBranch;
            final personMatch = selectedPerson == null || task['assignTo'] == selectedPerson;
            final statusMatch = selectedStatus == null || task['status'] == selectedStatus;
            final dateMatch = (startDate == null && endDate == null)
                || (task['date'] != null && (
                  (startDate == null || DateTime.fromMillisecondsSinceEpoch(task['date']).isAfter(startDate!.subtract(Duration(days: 1)))) &&
                  (endDate == null || DateTime.fromMillisecondsSinceEpoch(task['date']).isBefore(endDate!.add(Duration(days: 1))))
                ));
            return branchMatch && personMatch && statusMatch && dateMatch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Branch dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedBranch,
                        decoration: InputDecoration(labelText: 'Branch'),
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text('All')),
                          ...branches.map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedBranch = val;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    // Person dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPerson,
                        decoration: InputDecoration(labelText: 'Person'),
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text('All')),
                          ...persons.map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedPerson = val;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    // Status dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(labelText: 'Status'),
                        items: [
                          DropdownMenuItem<String>(value: null, child: Text('All')),
                          ...statuses.map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedStatus = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              startDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: 'Start Date'),
                          child: Text(startDate != null ? "${startDate!.day}/${startDate!.month}/${startDate!.year}" : 'Any'),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              endDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: 'End Date'),
                          child: Text(endDate != null ? "${endDate!.day}/${endDate!.month}/${endDate!.year}" : 'Any'),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.clear),
                      tooltip: 'Clear Dates',
                      onPressed: () {
                        setState(() {
                          startDate = null;
                          endDate = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Divider(),
              // Task list
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No tasks found.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final task = filtered[idx];
                          return ListTile(
                            title: Text(task['name'] ?? ''),
                            subtitle: Text('Assigned to: ${task['assignTo'] ?? ''}\nStatus: ${task['status'] ?? ''}'),
                            trailing: task['dueDate'] != null
                                ? Text('Due: ' + DateTime.fromMillisecondsSinceEpoch(task['dueDate']).toLocal().toString().split(' ')[0])
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
