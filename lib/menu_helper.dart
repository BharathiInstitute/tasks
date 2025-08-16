import 'package:flutter/material.dart';
// Permissions removed – menu always shows all standard panels now.

// Content index mapping (unchanged under the hood):
// 0 Tasks (now labeled View Tasks), 1 Projects, 2 Persons, 3 Branches, 4 Attendance, 5 Leaves,
// 6 Permissions (admin), 7 Attendance Correction (admin), 8 Leave Approvals (admin or leavesApprove),
// 9 My Tasks (user focused)
// 10 Employee Home (dashboard)
// 11 Practice Panel
// 12 Template Goals

class MenuHelper {
  static List<({IconData icon, String label, int? content})> buildRailItems(Set<String> allowed, bool isAdmin) {
    // Requested menu order (content indices remain stable):
  // 0 Home (content 10)
  // 1 My Tasks (content 9)
    // 2 Attendance (4)
    // 3 Leaves (5)
    // 4 View Tasks (0)
    // 5 Projects (1)
    // 6 Persons (2)
    // 7 Branches (3)
    // 8 Attendance Correction (7)
    // 9 Permissions (6)
    // 10 Logout
    final items = <({IconData icon, String label, int? content})>[
  (icon: Icons.home_outlined, label: 'Home', content: 10),
  (icon: Icons.list_alt_outlined, label: 'My Tasks', content: 9),
  (icon: Icons.school_outlined, label: 'Practice', content: 11),
  // Template Goals appears inside Data expansion only (content: 12) so not added directly here
      (icon: Icons.fingerprint_outlined, label: 'Attendance', content: 4),
  (icon: Icons.beach_access_outlined, label: 'Leaves', content: 5), // leaves always visible
      // Group first so Data appears before View Tasks
  (icon: Icons.folder_copy_outlined, label: 'Data', content: -1),
  (icon: Icons.task_alt_outlined, label: 'All Tasks', content: 0),
  (icon: Icons.fact_check_outlined, label: 'Leave Approvals', content: 8),
  (icon: Icons.edit_calendar, label: 'Attendance Correction', content: 7),
  (icon: Icons.admin_panel_settings_outlined, label: 'Permissions', content: 6),
      (icon: Icons.logout, label: 'Logout', content: null),
    ];
    return items;
  }

  static bool canViewContent(int contentIndex, Set<String> allowed, bool isAdmin) => true; // all visible
}
