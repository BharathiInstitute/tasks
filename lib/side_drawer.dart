import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SideDrawer extends StatelessWidget {
  final String displayName;
  final String displayEmail;
  final bool isAdmin;
  final void Function(int contentIndex, int navIndex) onSelect;

  const SideDrawer({
    super.key,
    required this.displayName,
    required this.displayEmail,
  required this.isAdmin,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
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

            // Home shortcut
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                close();
                onSelect(0, 0);
              },
            ),

            ExpansionTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: const Text('Tasks', style: TextStyle(fontWeight: FontWeight.w600)),
              children: const [],
            ),

            ExpansionTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Master Data', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: const Text('Projects'),
                  onTap: () {
                    close();
                    onSelect(1, 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('Persons'),
                  onTap: () {
                    close();
                    onSelect(2, 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_business_outlined),
                  title: const Text('Branches'),
                  onTap: () {
                    close();
                    onSelect(3, 3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Roles'),
                  onTap: () {
                    close();
                    onSelect(7, 7);
                  },
                ),
              ],
            ),

            ExpansionTile(
              leading: const Icon(Icons.fingerprint_outlined),
              title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dashboard'),
                  onTap: () {
                    close();
                    onSelect(4, 4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.beach_access_outlined),
                  title: const Text('Leaves'),
                  onTap: () {
                    close();
                    onSelect(5, 5);
                  },
                ),
              ],
            ),

            ExpansionTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: const Text('Tools', style: TextStyle(fontWeight: FontWeight.w600)),
              children: const [
                ListTile(
                  leading: Icon(Icons.filter_alt_outlined),
                  title: Text('Filters on Home'),
                  subtitle: Text('Use the filter panel at the bottom of Home'),
                ),
              ],
            ),

            const Divider(),

      ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Permissions'),
              onTap: () {
                close();
        onSelect(6, 6);
              },
            ),

            ListTile(
              leading: Icon(Icons.logout, color: Colors.red[700]),
              title: Text('Logout', style: TextStyle(color: Colors.red[700])),
              onTap: () async {
                close();
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
