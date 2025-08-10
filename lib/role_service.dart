import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  static const Set<String> adminEmails = {
    'kehsaram001@gmail.com',
  };

  static DocumentReference<Map<String, dynamic>> _roleDoc(String uid) =>
      FirebaseFirestore.instance.collection('roles').doc(uid);

  static Future<void> ensureRoleSet(User user) async {
    try {
      final doc = await _roleDoc(user.uid).get();
      final email = (user.email ?? '').toLowerCase();
      final isAdmin = adminEmails.contains(email);
      final role = isAdmin ? 'admin' : 'employee';
      if (!doc.exists || (doc.data()?['role'] != role)) {
        await _roleDoc(user.uid).set({
          'role': role,
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // no-op
    }
  }

  static Future<bool> fetchIsAdmin(User? user) async {
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult(true);
      final role = (token.claims?['role'] ?? '').toString();
      if (role.isNotEmpty) return role == 'admin';
    } catch (_) {}
    try {
      final doc = await _roleDoc(user.uid).get();
      return (doc.data()?['role'] ?? '') == 'admin';
    } catch (_) {
      // fall back to allowlist by email
      final email = (user.email ?? '').toLowerCase();
      return adminEmails.contains(email);
    }
  }

  /// Returns the role string for the user, e.g., 'admin' or 'employee'.
  static Future<String?> fetchRole(User? user) async {
    if (user == null) return null;
    try {
      final token = await user.getIdTokenResult(true);
      final claimRole = (token.claims?['role'] ?? '').toString();
      if (claimRole.isNotEmpty) return claimRole;
    } catch (_) {}
    try {
      final doc = await _roleDoc(user.uid).get();
      final role = (doc.data()?['role'] ?? '').toString();
      if (role.isNotEmpty) return role;
    } catch (_) {}
    final email = (user.email ?? '').toLowerCase();
    if (adminEmails.contains(email)) return 'admin';
    return 'employee';
  }
}
