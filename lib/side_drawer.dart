import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'permissions.dart';
import 'menu_helper.dart';
import 'responsive.dart';

class SideDrawer extends StatelessWidget {
  final String displayName;
  final String displayEmail;
  final bool isAdmin;
  final Set<String> allowed;
  final void Function(int contentIndex, int navIndex) onSelect;

  const SideDrawer({
    super.key,
    required this.displayName,
    required this.displayEmail,
    required this.isAdmin,
    required this.allowed,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();

    bool has(String key) => isAdmin || allowed.contains(key);

    Widget navRow({required IconData icon, required String label, Color? color, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              close();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: color ?? Colors.black87),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color ?? Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

  // Removed compact breakpoint variable (no longer needed after limiting expansions to wide screens)

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Determine layout width once
            Builder(builder: (context) { return const SizedBox.shrink(); }),
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[600]),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 24, color: Colors.blue[700], fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        if (displayEmail.isNotEmpty)
                          Text(
                            displayEmail,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation rows always shown on all sizes (mobile will hide only certain expansion groups below)
            navRow(
              icon: Icons.list_alt_outlined,
              label: 'My Tasks',
              onTap: () {
                final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 9);
                onSelect(9, navIdx < 0 ? 0 : navIdx);
              },
            ),
            navRow(
              icon: Icons.school_outlined,
              label: 'Practice',
              onTap: () {
                final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 11);
                onSelect(11, navIdx < 0 ? 0 : navIdx);
              },
            ),
            navRow(
              icon: Icons.fingerprint_outlined,
              label: 'Attendance',
              onTap: () {
                final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 4);
                onSelect(4, navIdx < 0 ? 0 : navIdx);
              },
            ),
            navRow(
              icon: Icons.beach_access_outlined,
              label: 'Leaves',
              onTap: () {
                final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 5);
                onSelect(5, navIdx < 0 ? 0 : navIdx);
              },
            ),
            // Master Data expansion: show only if user has at least one data view permission
            if (isAdmin ||
                allowed.contains(PermKeys.projectsView) ||
                allowed.contains(PermKeys.personsView) ||
                allowed.contains(PermKeys.branchesView))
              ExpansionTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: const Text('Data', style: TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  if (isAdmin || allowed.contains(PermKeys.projectsView))
                    navRow(
                      icon: Icons.work_outline,
                      label: 'Projects',
                      onTap: () {
                        final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 1);
                        onSelect(1, navIdx < 0 ? 0 : navIdx);
                      },
                    ),
                  if (isAdmin || allowed.contains(PermKeys.personsView))
                    navRow(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'Persons',
                      onTap: () {
                        final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 2);
                        onSelect(2, navIdx < 0 ? 0 : navIdx);
                      },
                    ),
                  if (isAdmin || allowed.contains(PermKeys.branchesView))
                    navRow(
                      icon: Icons.add_business_outlined,
                      label: 'Branches',
                      onTap: () {
                        final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 3);
                        onSelect(3, navIdx < 0 ? 0 : navIdx);
                      },
                    ),
                  // Template Goals (same Data permission grouping; show if user can view any data section or admin)
                  navRow(
                    icon: Icons.flag_outlined,
                    label: 'Template Goals',
                    onTap: () {
                      final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 12);
                      onSelect(12, navIdx < 0 ? 0 : navIdx);
                    },
                  ),
                ],
              ),
            if (isAdmin)
              navRow(
                icon: Icons.task_alt_outlined,
                label: 'View Tasks',
                onTap: () {
                  final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 0);
                  onSelect(0, navIdx < 0 ? 0 : navIdx);
                },
              ),
            if (isAdmin || allowed.contains(PermKeys.leavesApprove))
              navRow(
                icon: Icons.fact_check_outlined,
                label: 'Leave Approvals',
                onTap: () {
                  final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 8);
                  onSelect(8, navIdx < 0 ? 0 : navIdx);
                },
              ),
            if (isAdmin)
              navRow(
                icon: Icons.edit_calendar,
                label: 'Attendance Correction',
                onTap: () {
                  final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 7);
                  onSelect(7, navIdx < 0 ? 0 : navIdx);
                },
              ),
            if (isAdmin)
              navRow(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Permissions',
                onTap: () {
                  final navIdx = MenuHelper.buildRailItems(allowed, isAdmin).indexWhere((e) => e.content == 6);
                  onSelect(6, navIdx < 0 ? 0 : navIdx);
                },
              ),

            // Tasks expansion only on wide screens
            if (isWideWidth(context) && has(PermKeys.tasksView))
              ExpansionTile(
                leading: const Icon(Icons.task_alt_outlined),
                title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w600)),
                children: const [],
              ),

            // (Previous wide-only Master Data expansion removed; now always visible above)

            // Attendance expansion only on wide screens
            if (isWideWidth(context)) Builder(builder: (context) {
              final children = <Widget>[
                  navRow(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => onSelect(4, 4)),
                  navRow(icon: Icons.beach_access_outlined, label: 'Leaves', onTap: () => onSelect(5, 5)),
                  if (isAdmin)
                    navRow(icon: Icons.edit_calendar, label: 'Attendance Correction', onTap: () => onSelect(7, 7)),
                  if (isAdmin || has(PermKeys.leavesApprove))
                    navRow(icon: Icons.fact_check_outlined, label: 'Leave Approvals', onTap: () => onSelect(8, 8)),
              ];
              if (children.isEmpty) return const SizedBox.shrink();
              return ExpansionTile(
                leading: const Icon(Icons.fingerprint_outlined),
                title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
                children: children,
              );
            }),

            // Make Attendance Correction also a direct shortcut so admins don't need to expand the group
            // Leave Approvals removed from explicit menu per new sequence (still accessible if added back later)

            // Tools expansion only on wide screens
            if (isWideWidth(context))
              ExpansionTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('Tools', style: TextStyle(fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.filter_alt_outlined, size: 20),
                        SizedBox(width: 14),
                        Expanded(child: Text('Filters on Tasks\nUse the filter panel at bottom', style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
                ],
              ),

            const Divider(),

            // Removed duplicate bottom Permissions shortcut (already provided above when admin)

            navRow(
              icon: Icons.logout,
              label: 'Logout',
              color: Colors.red[700],
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
