import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';
import 'view_items_screen.dart';

class AddItemScreen extends StatefulWidget {
  AddItemScreen({super.key});

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final nameController = TextEditingController();
  final branchController = TextEditingController();
  final assignToController = TextEditingController();
  final notesController = TextEditingController();
  
  String selectedStatus = 'Pending';
  String selectedCategory = 'Graphics';
  DateTime? selectedDate;
  DateTime? selectedDueDate;
  String tokenNumber = '';
  
  final List<String> statusOptions = ['Pending', 'In Progress', 'Completed', 'On Hold'];
  final List<String> categoryOptions = ['Graphics', 'Video', 'Web'];
  final Map<String, String> categoryPrefixes = {
    'Graphics': 'G',
    'Video': 'V', 
    'Web': 'W',
  };

  @override
  void initState() {
    super.initState();
    _generateInitialToken();
  }

  void _generateInitialToken() async {
    await generateTokenNumber();
    setState(() {});
  }

  Future<String> generateTokenNumber() async {
    String prefix = categoryPrefixes[selectedCategory] ?? 'G';
    
    // Get the next sequential number for this category
    DatabaseReference counterRef = FirebaseDatabase.instance.ref('counters/$prefix');
    
    try {
      DataSnapshot snapshot = await counterRef.get();
      int nextNumber = 1;
      
      if (snapshot.exists) {
        nextNumber = (snapshot.value as int) + 1;
      }
      
      // Update the counter
      await counterRef.set(nextNumber);
      
      // Format as 4-digit number with leading zeros
      String sequentialNumber = nextNumber.toString().padLeft(4, '0');
      tokenNumber = '$prefix$sequentialNumber';
      
      return tokenNumber;
    } catch (e) {
      // Fallback to random if database fails
      final random = Random();
      final randomNum = random.nextInt(9000) + 1000;
      tokenNumber = '$prefix$randomNum';
      return tokenNumber;
    }
  }

  void addItem() async {
    final name = nameController.text.trim();
    final branch = branchController.text.trim();
    final assignTo = assignToController.text.trim();
    final notes = notesController.text.trim();
    
    if (name.isNotEmpty && branch.isNotEmpty && assignTo.isNotEmpty) {
      // Generate fresh token before saving
      String currentToken = await generateTokenNumber();
      
      DatabaseReference ref = FirebaseDatabase.instance.ref('items').push();
      ref.set({
        'id': ref.key,
        'tokenNumber': currentToken,
        'category': selectedCategory,
        'name': name,
        'branch': branch,
        'assignTo': assignTo,
        'status': selectedStatus,
        'date': selectedDate?.millisecondsSinceEpoch,
        'dueDate': selectedDueDate?.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      nameController.clear();
      branchController.clear();
      assignToController.clear();
      notesController.clear();
      setState(() {
        selectedStatus = 'Pending';
        selectedDate = null;
        selectedDueDate = null;
        // Generate new token for next task
        _generateInitialToken();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task added successfully! Token: $currentToken')),
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
              // Token Number Display
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token Number',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tokenNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: categoryOptions.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text('$category (${categoryPrefixes[category]})'),
                  );
                }).toList(),
                onChanged: (String? newValue) async {
                  setState(() {
                    selectedCategory = newValue!;
                  });
                  // Regenerate token with new category prefix
                  await generateTokenNumber();
                  setState(() {});
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
              TextField(
                controller: branchController,
                decoration: InputDecoration(
                  labelText: 'Branch *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: assignToController,
                decoration: InputDecoration(
                  labelText: 'Assign To *',
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
