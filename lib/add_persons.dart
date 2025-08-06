import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({Key? key}) : super(key: key);

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String? selectedBranch;
  List<String> branchOptions = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('branches').get();
      setState(() {
        branchOptions = snapshot.docs.map((doc) => doc['name'] as String).toList();
        if (branchOptions.isNotEmpty) {
          selectedBranch ??= branchOptions.first;
        }
      });
    } catch (e) {
      setState(() {
        branchOptions = ['Graphics', 'Video', 'Web'];
        selectedBranch = branchOptions.first;
      });
    }
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a branch.')),
      );
      return;
    }
    setState(() { isLoading = true; });
    try {
      await FirebaseFirestore.instance.collection('persons').add({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'branch': selectedBranch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Person added successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving person: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Person'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBranch,
                      decoration: InputDecoration(
                        labelText: 'Branch',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.business, color: Colors.blue[600]),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      items: branchOptions.map((branch) => DropdownMenuItem(
                        value: branch,
                        child: Text(branch),
                      )).toList(),
                      onChanged: (val) => setState(() => selectedBranch = val),
                      validator: (val) => val == null || val.isEmpty ? 'Please select a branch' : null,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.person, color: Colors.blue[600]),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.phone, color: Colors.blue[600]),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.trim().length < 10 ? 'Enter valid phone number' : null,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'Email ID',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.email, color: Colors.blue[600]),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter email';
                        if (!val.contains('@') || !val.contains('.')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _savePerson,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
