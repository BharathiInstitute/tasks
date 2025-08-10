import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'role_service.dart';

/// Permission keys used to gate navigation/menu visibility.
/// Keep these in sync with Home content indexes.
class PermKeys {
  // Legacy screen toggles (kept for compatibility where referenced)
  static const String home = 'home';
  static const String projects = 'projects';
  static const String persons = 'persons';
  static const String branches = 'branches';
  static const String attendance = 'attendance';
  static const String leaves = 'leaves';

  // New action-based permissions per module
  static const String homeView = 'homeView';
  static const String homeEdit = 'homeEdit';
  static const String homeDelete = 'homeDelete';

  static const String projectsView = 'projectsView';
  static const String projectsEdit = 'projectsEdit';
  static const String projectsDelete = 'projectsDelete';

  static const String personsView = 'personsView';
  static const String personsEdit = 'personsEdit';
  static const String personsDelete = 'personsDelete';

  static const String branchesView = 'branchesView';
  static const String branchesEdit = 'branchesEdit';
  static const String branchesDelete = 'branchesDelete';

  static const String attendanceView = 'attendanceView';
  static const String attendanceEdit = 'attendanceEdit';
  static const String attendanceDelete = 'attendanceDelete';

  static const String leavesView = 'leavesView';
  static const String leavesEdit = 'leavesEdit';
  static const String leavesDelete = 'leavesDelete';

  static const String tasksView = 'tasksView';
  static const String tasksEdit = 'tasksEdit';
  static const String tasksDelete = 'tasksDelete';
  // Task field-level edit permissions
  static const String taskEditTitle = 'taskEditTitle';
  static const String taskEditNotes = 'taskEditNotes';
  static const String taskEditStatus = 'taskEditStatus';
  static const String taskEditPriority = 'taskEditPriority';
  static const String taskEditProject = 'taskEditProject';
  static const String taskEditBranch = 'taskEditBranch';
  static const String taskEditAssignee = 'taskEditAssignee';
  static const String taskEditDueDate = 'taskEditDueDate';
}

class PermissionsService {
  static final _db = FirebaseFirestore.instance;

  /// For a signed-in user, fetch their role and resolve allowed keys.
  static Future<Set<String>> fetchAllowedKeysForUser(User? user) async {
    final role = await RoleService.fetchRole(user) ?? 'employee';
    return fetchAllowedKeysForRole(role);
  }

  /// Load allowed permission keys for a role from Firestore: roleDefs/{role}
  /// Document shape: { allowed: ['home','projects', ...] }
  /// Provides safe defaults when missing.
  static Future<Set<String>> fetchAllowedKeysForRole(String role) async {
    try {
      final snap = await _db.collection('roleDefs').doc(role).get();
      final data = snap.data();
      if (data != null && data['allowed'] is List) {
        final list = List<String>.from(data['allowed']);
        return list.toSet();
      }
    } catch (_) {
      // fall through to defaults
    }
    // Defaults: admin gets all; employee limited
    if (role.toLowerCase() == 'admin') {
      return {
        // Legacy allowances
        PermKeys.home,
        PermKeys.projects,
        PermKeys.persons,
        PermKeys.branches,
        PermKeys.attendance,
        PermKeys.leaves,
        // View/Edit/Delete for all modules
        PermKeys.homeView, PermKeys.homeEdit, PermKeys.homeDelete,
        PermKeys.projectsView, PermKeys.projectsEdit, PermKeys.projectsDelete,
        PermKeys.personsView, PermKeys.personsEdit, PermKeys.personsDelete,
        PermKeys.branchesView, PermKeys.branchesEdit, PermKeys.branchesDelete,
        PermKeys.attendanceView, PermKeys.attendanceEdit, PermKeys.attendanceDelete,
        PermKeys.leavesView, PermKeys.leavesEdit, PermKeys.leavesDelete,
        PermKeys.tasksView, PermKeys.tasksEdit, PermKeys.tasksDelete,
        // Task field-level
        PermKeys.taskEditTitle,
        PermKeys.taskEditNotes,
        PermKeys.taskEditStatus,
        PermKeys.taskEditPriority,
        PermKeys.taskEditProject,
        PermKeys.taskEditBranch,
        PermKeys.taskEditAssignee,
        PermKeys.taskEditDueDate,
      };
    }
    return {
      // Legacy
      PermKeys.home,
      PermKeys.attendance,
      PermKeys.leaves,
      // Default employee: view-only for a few modules
      PermKeys.homeView,
  PermKeys.projectsView,
  PermKeys.personsView,
  PermKeys.branchesView,
      PermKeys.attendanceView,
      PermKeys.leavesView,
    };
  }

  /// Fetch allowed keys for a specific email from Firestore: userPerms/{email}
  /// If missing or invalid, fallback to the user's role default behavior.
  static Future<Set<String>> fetchAllowedKeysForEmail(String email) async {
    try {
      if (email.trim().isEmpty) return {};
      final snap = await _db.collection('userPerms').doc(email).get();
      final data = snap.data();
      if (data != null && data['allowed'] is List) {
        final userSet = List<String>.from(data['allowed']).toSet();
        // Merge in role defaults to guarantee baseline read access
        final baseline = await _fallbackByRole(email);
        return {...baseline, ...userSet};
      }
    } catch (_) {
      // ignore and fallback
    }
    return _fallbackByRole(email);
  }

  static Future<Set<String>> _fallbackByRole(String email) async {
    // Determine role by looking up person by email, else default employee
    try {
      final q = await _db.collection('persons').where('email', isEqualTo: email).limit(1).get();
      String role = 'employee';
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        final r = (d['role'] ?? '').toString().trim();
        if (r.isNotEmpty) role = r.toLowerCase();
      }
      return fetchAllowedKeysForRole(role);
    } catch (_) {
      return fetchAllowedKeysForRole('employee');
    }
  }
}
