// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_tasks_new.dart';
import 'permissions.dart';

class EmployeeHome extends StatefulWidget {
  final String employeeName;
  const EmployeeHome({super.key, required this.employeeName});

  @override
  @override
  EmployeeHomeState createState() => EmployeeHomeState();
}

class EmployeeHomeState extends State<EmployeeHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedStatus;
  DateTime? startDate;
  DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Tasks'),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.add_task, color: Colors.white),
            label: Text('Add Task', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 226, 88, 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              // Fetch allowed permission keys for current user email (simple reuse of permissions service)
              final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
              Set<String> allowed = {};
              try {
                if (email.isNotEmpty) {
                  allowed = await PermissionsService.fetchAllowedKeysForEmail(email);
                }
              } catch (_) {}
              if (!mounted) return;
              if (!allowed.contains(PermKeys.tasksAdd)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No permission to add tasks')));
                return;
              }
              showAddTaskDialog(context, allowed: allowed);
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('tasks').where('assignTo', isEqualTo: widget.employeeName).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No tasks found.'));
          }
          final tasks = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

          final statuses = [
            'Working',
            'Pending',
            'Completed',
          ];

          List<Map<String, dynamic>> filtered = tasks.where((task) {
            final statusMatch = selectedStatus == null || task['status'] == selectedStatus;
            final dateMatch = (startDate == null && endDate == null)
                || (task['date'] != null && (
                  (startDate == null || DateTime.fromMillisecondsSinceEpoch(task['date']).isAfter(startDate!.subtract(Duration(days: 1)))) &&
                  (endDate == null || DateTime.fromMillisecondsSinceEpoch(task['date']).isBefore(endDate!.add(Duration(days: 1))) )
                ));
            return statusMatch && dateMatch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
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
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No tasks found.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final task = filtered[idx];
                          return ListTile(
                            title: Text(task['name'] ?? ''),
                            subtitle: Text('Status: ${task['status'] ?? ''}'),
                            trailing: task['dueDate'] != null
                                ? Text('Due: ${DateTime.fromMillisecondsSinceEpoch(task['dueDate']).toLocal().toString().split(' ')[0]}')
                                : null,
                            onTap: () async {
                              // Open add-task popup (edit flow can be added later)
                              final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
                              Set<String> allowed = {};
                              try {
                                if (email.isNotEmpty) {
                                  allowed = await PermissionsService.fetchAllowedKeysForEmail(email);
                                }
                              } catch (_) {}
                              if (!mounted) return;
                              if (!allowed.contains(PermKeys.tasksView)) return;
                              showAddTaskDialog(context, existing: task, allowed: allowed);
                            },
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
