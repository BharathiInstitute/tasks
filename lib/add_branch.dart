import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddBranchDialog extends StatefulWidget {
  final List<String> branchOptions;
  final FirebaseFirestore firestore;
  final VoidCallback? onBranchAdded;

  const AddBranchDialog({
    Key? key,
    required this.branchOptions,
    required this.firestore,
    this.onBranchAdded,
  }) : super(key: key);

  @override
  State<AddBranchDialog> createState() => _AddBranchDialogState();
}

class _AddBranchDialogState extends State<AddBranchDialog> {
  final TextEditingController newBranchController = TextEditingController();
  bool isLoading = false;

  Future<void> _addNewBranch(String branchName) async {
    try {
      if (branchName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Branch name cannot be empty'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (widget.branchOptions.contains(branchName.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Branch already exists'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() { isLoading = true; });
      await widget.firestore.collection('branches').add({'name': branchName.trim()});
      setState(() { isLoading = false; });
      if (widget.onBranchAdded != null) widget.onBranchAdded!();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Branch "$branchName" added successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding branch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: Row(
        children: [
          Icon(Icons.add_business, color: Colors.green[600], size: 24),
          SizedBox(width: 12),
          Text(
            'Add New Branch',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the name of the new branch:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: newBranchController,
              decoration: InputDecoration(
                labelText: 'Branch Name',
                hintText: 'e.g., Marketing, Design, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.business, color: Colors.green[600]),
                filled: true,
                fillColor: Colors.green[50],
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : () {
            _addNewBranch(newBranchController.text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: isLoading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Add Branch', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
