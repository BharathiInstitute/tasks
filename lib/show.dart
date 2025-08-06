import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShowMenuScreen extends StatelessWidget {
  const ShowMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Show Menu'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.account_tree, color: Colors.white),
            tooltip: 'Show Branches',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShowBranchesScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person, color: Colors.white),
            tooltip: 'Show Persons',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShowPersonsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text('Select a menu option above to view branches or persons.', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class ShowBranchesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Branches'),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Branches', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => ShowPersonsScreen()),
              );
            },
            child: Text('Persons', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('branches').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No branches found.'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? ''),
                subtitle: data['description'] != null ? Text(data['description']) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                      onPressed: () async {
                        final nameController = TextEditingController(text: data['name'] ?? '');
                        final descController = TextEditingController(text: data['description'] ?? '');
                        final result = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Edit Branch'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(labelText: 'Name'),
                                ),
                                TextField(
                                  controller: descController,
                                  decoration: InputDecoration(labelText: 'Description'),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, {
                                    'name': nameController.text.trim(),
                                    'description': descController.text.trim(),
                                  });
                                },
                                child: Text('Save'),
                              ),
                            ],
                          ),
                        );
                        if (result != null) {
                          await FirebaseFirestore.instance.collection('branches').doc(doc.id).update({
                            'name': result['name'],
                            'description': result['description'],
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete Branch'),
                            content: Text('Are you sure you want to delete this branch?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Delete'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance.collection('branches').doc(doc.id).delete();
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class ShowPersonsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Persons'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => ShowBranchesScreen()),
              );
            },
            child: Text('Branches', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {},
            child: Text('Persons', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('persons').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No persons found.'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              String subtitle = 'Branch: ${data['branch'] ?? ''}';
              if ((data['number'] ?? '').toString().isNotEmpty) {
                subtitle += '\nNumber: ${data['number']}';
              }
              if ((data['email'] ?? '').toString().isNotEmpty) {
                subtitle += '\nEmail: ${data['email']}';
              }
              return ListTile(
                title: Text(data['name'] ?? ''),
                subtitle: Text(subtitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                      onPressed: () async {
                        final nameController = TextEditingController(text: data['name'] ?? '');
                        // Fetch all branches for dropdown
                        List<String> branchOptions = [];
                        try {
                          final branchSnap = await FirebaseFirestore.instance.collection('branches').get();
                          branchOptions = branchSnap.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'] ?? '').where((e) => e != '').cast<String>().toList();
                        } catch (_) {}
                        String selectedBranch = data['branch'] ?? (branchOptions.isNotEmpty ? branchOptions.first : '');
                        final emailController = TextEditingController(text: data['email'] ?? '');
                        final numberController = TextEditingController(text: (data.containsKey('number') && data['number'] != null) ? data['number'].toString() : '');
                        final result = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Edit Person'),
                            content: StatefulBuilder(
                              builder: (context, setState) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    controller: nameController,
                                    decoration: InputDecoration(labelText: 'Name'),
                                  ),
                                  DropdownButtonFormField<String>(
                                    value: selectedBranch.isNotEmpty ? selectedBranch : null,
                                    decoration: InputDecoration(labelText: 'Branch'),
                                    items: branchOptions.map((b) => DropdownMenuItem<String>(value: b, child: Text(b))).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        selectedBranch = val ?? '';
                                      });
                                    },
                                  ),
                                  TextField(
                                    controller: emailController,
                                    decoration: InputDecoration(labelText: 'Email'),
                                  ),
                                  TextField(
                                    controller: numberController,
                                    decoration: InputDecoration(labelText: 'Number'),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, {
                                    'name': nameController.text.trim(),
                                    'branch': selectedBranch,
                                    'email': emailController.text.trim(),
                                    'number': numberController.text.trim(),
                                  });
                                },
                                child: Text('Save'),
                              ),
                            ],
                          ),
                        );
                        if (result != null) {
                          await FirebaseFirestore.instance.collection('persons').doc(doc.id).update({
                            'name': result['name'],
                            'branch': result['branch'],
                            'email': result['email'],
                            'number': result['number'],
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete Person'),
                            content: Text('Are you sure you want to delete this person?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Delete'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseFirestore.instance.collection('persons').doc(doc.id).delete();
                        }
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
