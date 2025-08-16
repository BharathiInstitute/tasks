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
  // static const String roles = 'roles'; // removed UI usage

  // New action-based permissions per module
  static const String homeView = 'homeView';
  static const String homeEdit = 'homeEdit';
  static const String homeDelete = 'homeDelete';

  static const String projectsView = 'projectsView';
  static const String projectsAdd = 'projectsAdd';
  static const String projectsEdit = 'projectsEdit';
  static const String projectsDelete = 'projectsDelete';

  static const String personsView = 'personsView';
  static const String personsAdd = 'personsAdd';
  static const String personsEdit = 'personsEdit';
  static const String personsDelete = 'personsDelete';

  static const String branchesView = 'branchesView';
  static const String branchesAdd = 'branchesAdd';
  static const String branchesEdit = 'branchesEdit';
  static const String branchesDelete = 'branchesDelete';

  // Attendance & Leaves base access now granted to all users; keep only approve key.
  static const String attendanceView = 'attendanceView'; // retained for backward compat (ignored)
  static const String attendanceEdit = 'attendanceEdit'; // unused
  static const String attendanceDelete = 'attendanceDelete'; // unused

  static const String leavesView = 'leavesView'; // retained for backward compat (ignored)
  static const String leavesEdit = 'leavesEdit'; // unused
  static const String leavesDelete = 'leavesDelete'; // unused
  static const String leavesApprove = 'leavesApprove';

  // Roles module permissions
  // Roles module permissions removed

  static const String tasksView = 'tasksView';
  static const String tasksAdd = 'tasksAdd';
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
  // Separate filter visibility permissions
  static const String branchFilterView = 'branchFilterView';
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
  PermKeys.projectsAdd,
  PermKeys.personsView, PermKeys.personsEdit, PermKeys.personsDelete, PermKeys.personsAdd,
  PermKeys.branchesView, PermKeys.branchesEdit, PermKeys.branchesDelete, PermKeys.branchesAdd,
  // Attendance/Leaves granular perms deprecated; approve retained
  PermKeys.leavesApprove,
        PermKeys.tasksView, PermKeys.tasksEdit, PermKeys.tasksDelete,
  PermKeys.tasksAdd,
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
  // Allow employees to view tasks they are assigned (rules also allow assignee access)
  PermKeys.tasksView,
  // Attendance & Leaves always accessible (implicit)
    };
  }

  /// Fetch allowed keys for a specific email from Firestore: userPerms/{email}
  /// If missing or invalid, fallback to the user's role default behavior.
  static Future<Set<String>> fetchAllowedKeysForEmail(String email) async {
    try {
      final raw = email.trim();
      if (raw.isEmpty) return {};
      final key = raw.toLowerCase();
      final snap = await _db.collection('userPerms').doc(key).get();
      final data = snap.data();
      if (data != null && data['allowed'] is List) {
  final userSet = List<String>.from(data['allowed']).toSet();
  // Use the explicit per-email set as the source of truth when present
  return userSet;
      }
    } catch (_) {
      // ignore and fallback
    }
    return _fallbackByRole(email.trim());
  }

  /// Strict per-email fetch: returns null when there is no userPerms doc for the email.
  /// If the doc exists, returns the exact saved set (can be empty to mean no permissions).
  static Future<Set<String>?> fetchExplicitKeysForEmailOrNull(String email) async {
    try {
      final raw = email.trim();
      if (raw.isEmpty) return null;
      final key = raw.toLowerCase();
      final snap = await _db.collection('userPerms').doc(key).get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data != null && data['allowed'] is List) {
        return List<String>.from(data['allowed']).toSet();
      }
      // Doc exists but no list present -> treat as empty explicit set
      return <String>{};
    } catch (_) {
      return null;
    }
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
