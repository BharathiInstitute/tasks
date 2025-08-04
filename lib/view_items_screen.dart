import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ViewItemsScreen extends StatefulWidget {
  const ViewItemsScreen({super.key});

  @override
  _ViewItemsScreenState createState() => _ViewItemsScreenState();
}

class _ViewItemsScreenState extends State<ViewItemsScreen> {
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('items');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void deleteItem(String id) {
    _ref.child(id).remove();
  }

  void showEditDialog(Map item) {
    final nameController = TextEditingController(text: item['name']);
    final branchController = TextEditingController(text: item['branch']);
    final assignToController = TextEditingController(text: item['assignTo']);
    final notesController = TextEditingController(text: item['notes']);
    String selectedStatus = item['status'] ?? 'Pending';

    final List<String> statusOptions = ['Pending', 'In Progress', 'Completed', 'On Hold'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Task Name'),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: branchController,
                  decoration: InputDecoration(labelText: 'Branch'),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: assignToController,
                  decoration: InputDecoration(labelText: 'Assign To'),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(labelText: 'Status'),
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
                SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                _ref.child(item['id']).update({
                  'name': nameController.text.trim(),
                  'branch': branchController.text.trim(),
                  'assignTo': assignToController.text.trim(),
                  'status': selectedStatus,
                  'notes': notesController.text.trim(),
                });
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Tasks'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by token number or task name...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder(
        stream: _ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            Map data = snapshot.data!.snapshot.value as Map;
            List items = data.values.toList();
            
            // Filter items based on search query
            if (_searchQuery.isNotEmpty) {
              items = items.where((item) {
                final name = (item['name'] ?? '').toString().toLowerCase();
                final token = (item['tokenNumber'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || token.contains(_searchQuery);
              }).toList();
            }

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty ? 'No tasks found matching your search' : 'No tasks found',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                var item = items[index];
                DateTime? date = item['date'] != null ? DateTime.fromMillisecondsSinceEpoch(item['date']) : null;
                DateTime? dueDate = item['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(item['dueDate']) : null;
                
                // Determine status color
                Color statusColor = Colors.grey;
                switch (item['status']) {
                  case 'Pending':
                    statusColor = Colors.orange;
                    break;
                  case 'In Progress':
                    statusColor = Colors.blue;
                    break;
                  case 'Completed':
                    statusColor = Colors.green;
                    break;
                  case 'On Hold':
                    statusColor = Colors.red;
                    break;
                }

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Token Number and Status Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'No Name',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Token: ${item['tokenNumber'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      if (item['category'] != null) ...[
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item['category'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[800],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item['status'] ?? 'Pending',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.business, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text('Branch: ${item['branch'] ?? 'Not specified'}'),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text('Assigned to: ${item['assignTo'] ?? 'Not assigned'}'),
                          ],
                        ),
                        if (date != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Text('Date: ${date.day}/${date.month}/${date.year}'),
                            ],
                          ),
                        ],
                        if (dueDate != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.event, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Text('Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                            ],
                          ),
                        ],
                        if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                          SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Notes: ${item['notes']}'),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => showEditDialog(item),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteItem(item['id']),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tasks found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
