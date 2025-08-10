import 'package:firebase_auth/firebase_auth.dart';
import 'add_tasks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'manage_projects.dart';
import 'manage_branches.dart';
import 'manage_persons.dart';
import 'manage_roles.dart';
import 'responsive.dart';
import 'attendance_dashboard.dart';
import 'leaves_panel.dart';
import 'role_service.dart';
import 'side_drawer.dart';
import 'permissions_admin.dart';
import 'permissions.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Color _statusColor(String s) {
    final status = (s).toLowerCase();
    if (status.contains('done') || status.contains('complete')) return Colors.green.shade600;
    if (status.contains('progress')) return Colors.blue.shade600;
    if (status.contains('block') || status.contains('hold')) return Colors.red.shade600;
    if (status.contains('start') || status.contains('todo') || status.contains('pending')) return Colors.orange.shade700;
    return Colors.grey.shade700;
  }

  String _displayName = 'User';
  String _displayEmail = '';
  bool _isAdmin = false;
  Set<String> _allowed = {};
  bool _permsLoading = false;

  void _ensureIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      final email = (user.email ?? '').trim();
      final name = (user.displayName ?? '').trim();
      _displayName = name.isNotEmpty
          ? name
          : (email.isNotEmpty ? email.split('@').first : 'User');
      _displayEmail = email.isNotEmpty ? email : 'unknown@example.com';
    } else {
      const firstNames = ['Alex', 'Taylor', 'Jordan', 'Casey', 'Riley', 'Avery', 'Morgan', 'Quinn'];
      const lastNames = ['Smith', 'Johnson', 'Lee', 'Patel', 'Garcia', 'Brown', 'Davis', 'Miller'];
      final r = Random();
      final first = firstNames[r.nextInt(firstNames.length)];
      final last = lastNames[r.nextInt(lastNames.length)];
      final num = 1000 + r.nextInt(9000);
      _displayName = '$first $last';
      _displayEmail = '${first.toLowerCase()}.${last.toLowerCase()}$num@example.com';
    }
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = await RoleService.fetchIsAdmin(user);
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedBranch;
  String? selectedPerson;
  String? selectedStatus;
  String? selectedProject;
  DateTime? startDate;
  DateTime? endDate;
  List<String> allBranches = [];
  List<String> allPersons = [];
  List<String> allProjects = [];
  bool _onlyMyTasks = false;

  @override
  void initState() {
    super.initState();
    _ensureIdentity();
    _loadPerms();
    fetchBranchesAndPersons();
    fetchProjects();
    _loadRole();
  }

  Future<void> _loadPerms() async {
    setState(() => _permsLoading = true);
    try {
      final allowed = await PermissionsService.fetchAllowedKeysForEmail(_displayEmail);
      if (mounted) setState(() => _allowed = allowed);
    } finally {
      if (mounted) setState(() => _permsLoading = false);
    }
  }

  bool _has(String key) => _isAdmin || _allowed.contains(key);

  void fetchBranchesAndPersons() async {
    final branchSnap = await _firestore.collection('branches').get();
    final personSnap = await _firestore.collection('persons').get();
    setState(() {
      allBranches = branchSnap.docs.map((doc) => (doc.data()['name'] ?? '') as String).where((e) => e != '').toList();
      allPersons = personSnap.docs.map((doc) => (doc.data()['name'] ?? '') as String).where((e) => e != '').toList();
    });
  }

  void fetchProjects() async {
    final projectSnap = await _firestore.collection('projects').get();
    setState(() {
      allProjects = projectSnap.docs.map((doc) => (doc.data()['name'] ?? '') as String).where((e) => e != '').toList();
    });
  }

  bool _railExtended = true;
  int _selectedNavIndex = 0; // highlights current nav destination
  int _contentIndex = 0; // 0 Home, 1 Projects, 2 Persons, 3 Branches, 4 Attendance, 5 Leaves, 6 Permissions, 7 Roles

  Widget _buildCenterContent() {
    switch (_contentIndex) {
      case 0:
        return _buildTaskContent();
      case 1:
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: ManageProjectsPanel(),
        );
      case 2:
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: ManagePersonsPanel(),
        );
      case 3:
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: ManageBranchesPanel(),
        );
      case 4:
        return const AttendancePanel();
      case 5:
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: LeavesPanel(),
        );
      case 6:
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: PermissionsAdminPanel(),
        );
      case 7:
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: ManageRolesPanel(),
        );
      default:
        return _buildTaskContent();
    }
  }

  Widget _buildNavRail(BuildContext context) {
    return NavigationRail(
      extended: _railExtended,
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (idx) async {
        switch (idx) {
          case 0:
            setState(() { _contentIndex = 0; _selectedNavIndex = 0; });
            break;
          case 1:
            if (!_has(PermKeys.projectsView)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No permission to view Projects.")));
              return;
            }
            setState(() { _contentIndex = 1; _selectedNavIndex = 1; });
            break;
          case 2:
            if (!_has(PermKeys.personsView)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No permission to view Persons.")));
              return;
            }
            setState(() { _contentIndex = 2; _selectedNavIndex = 2; });
            break;
          case 3:
            if (!_has(PermKeys.branchesView)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No permission to view Branches.")));
              return;
            }
            setState(() { _contentIndex = 3; _selectedNavIndex = 3; });
            break;
          case 4:
            if (!_has(PermKeys.attendanceView)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No permission to view Attendance.")));
              return;
            }
            setState(() { _contentIndex = 4; _selectedNavIndex = 4; });
            break;
          case 5:
            if (!_has(PermKeys.leavesView)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No permission to view Leaves.")));
              return;
            }
            setState(() { _contentIndex = 5; _selectedNavIndex = 5; });
            break;
          case 6:
            setState(() { _contentIndex = 6; _selectedNavIndex = 6; });
            break;
          case 7:
            setState(() { _contentIndex = 7; _selectedNavIndex = 7; });
            break;
          case 8:
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            }
            break;
        }
      },
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
              ),
            ),
            if (_railExtended) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (_displayEmail.isNotEmpty)
                      Text(
                        _displayEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.work_outline), label: Text('Projects')),
        NavigationRailDestination(icon: Icon(Icons.person_add_alt_1_outlined), label: Text('Persons')),
        NavigationRailDestination(icon: Icon(Icons.add_business_outlined), label: Text('Branches')),
        NavigationRailDestination(icon: Icon(Icons.fingerprint_outlined), label: Text('Attendance')),
        NavigationRailDestination(icon: Icon(Icons.beach_access_outlined), label: Text('Leaves')),
        NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: Text('Permissions')),
        NavigationRailDestination(icon: Icon(Icons.security_outlined), label: Text('Roles')),
        NavigationRailDestination(icon: Icon(Icons.logout), label: Text('Logout')),
      ],
    );
  }

  Widget _buildTaskContent() {
    if (_permsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_has(PermKeys.tasksView)) {
      return const Center(child: Text("You don't have permission to view tasks."));
    }
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tasks').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No tasks found.'));
        }
        List<Map<String, dynamic>> tasks = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        if (_onlyMyTasks) {
          tasks = tasks.where((t) {
            final assigneeUid = (t['assigneeUid'] ?? '').toString();
            final assignTo = (t['assignTo'] ?? '').toString();
            final email = (t['assigneeEmail'] ?? '').toString();
            return (uid != null && assigneeUid == uid) ||
                   (assignTo.isNotEmpty && assignTo.toLowerCase() == _displayName.toLowerCase()) ||
                   (_displayEmail.isNotEmpty && email.toLowerCase() == _displayEmail.toLowerCase());
          }).toList();
        }

        final branches = allBranches;
        final persons = allPersons;
        final statuses = <String>{
          ...tasks.map((t) => (t['status'] ?? '').toString()).where((s) => s.isNotEmpty),
          'Todo', 'In Progress', 'Blocked', 'Done',
        }.toList();

        List<Map<String, dynamic>> filtered = tasks.where((task) {
          final projectMatch = selectedProject == null || task['project'] == selectedProject;
          final branchMatch = selectedBranch == null || task['branch'] == selectedBranch;
          final personMatch = selectedPerson == null || task['assignTo'] == selectedPerson;
          final statusMatch = selectedStatus == null || task['status'] == selectedStatus;
          final int? taskDateMs = (task['dueDate'] ?? task['date']) is int ? (task['dueDate'] ?? task['date']) as int : null;
          final dateMatch = (startDate == null && endDate == null)
              || (taskDateMs != null && (
                (startDate == null || DateTime.fromMillisecondsSinceEpoch(taskDateMs).isAfter(startDate!.subtract(const Duration(days: 1)))) &&
                (endDate == null || DateTime.fromMillisecondsSinceEpoch(taskDateMs).isBefore(endDate!.add(const Duration(days: 1))))
              ));
          return projectMatch && branchMatch && personMatch && statusMatch && dateMatch;
        }).toList();

        final compact = isCompactWidth(context);

        return Column(
          children: [
            // Filters at top
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (!compact) ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedProject,
                                decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work_outline)),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All')),
                                  ...allProjects.map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                                ],
                                onChanged: (val) => setState(() => selectedProject = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedBranch,
                                decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All')),
                                  ...branches.map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                                ],
                                onChanged: (val) => setState(() => selectedBranch = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedPerson,
                                decoration: const InputDecoration(labelText: 'Assignee', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All')),
                                  ...persons.map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                                ],
                                onChanged: (val) => setState(() => selectedPerson = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedStatus,
                                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_outlined)),
                                items: [
                                  const DropdownMenuItem<String>(value: null, child: Text('All')),
                                  ...statuses.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                ],
                                onChanged: (val) => setState(() => selectedStatus = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      startDate = picked.start;
                                      endDate = picked.end;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.date_range),
                                label: Text(startDate == null && endDate == null
                                    ? 'Any date'
                                    : '${startDate?.year}-${startDate?.month.toString().padLeft(2, '0')}-${startDate?.day.toString().padLeft(2, '0')} -> ${endDate?.year}-${endDate?.month.toString().padLeft(2, '0')}-${endDate?.day.toString().padLeft(2, '0')}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'Clear filters',
                              onPressed: () => setState(() {
                                selectedProject = null;
                                selectedBranch = null;
                                selectedPerson = null;
                                selectedStatus = null;
                                startDate = null;
                                endDate = null;
                              }),
                              icon: const Icon(Icons.clear),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Only my tasks'),
                                Switch.adaptive(
                                  value: _onlyMyTasks,
                                  onChanged: (v) => setState(() => _onlyMyTasks = v),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          value: selectedProject,
                          decoration: const InputDecoration(labelText: 'Project', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work_outline)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All')),
                            ...allProjects.map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                          ],
                          onChanged: (val) => setState(() => selectedProject = val),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedBranch,
                          decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All')),
                            ...branches.map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                          ],
                          onChanged: (val) => setState(() => selectedBranch = val),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedPerson,
                          decoration: const InputDecoration(labelText: 'Assignee', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All')),
                            ...persons.map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                          ],
                          onChanged: (val) => setState(() => selectedPerson = val),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag_outlined)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('All')),
                            ...statuses.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                          ],
                          onChanged: (val) => setState(() => selectedStatus = val),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                startDate = picked.start;
                                endDate = picked.end;
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(startDate == null && endDate == null
                              ? 'Any date'
                              : '${startDate?.year}-${startDate?.month.toString().padLeft(2, '0')}-${startDate?.day.toString().padLeft(2, '0')} -> ${endDate?.year}-${endDate?.month.toString().padLeft(2, '0')}-${endDate?.day.toString().padLeft(2, '0')}'),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Clear filters',
                                onPressed: () => setState(() {
                                  selectedProject = null;
                                  selectedBranch = null;
                                  selectedPerson = null;
                                  selectedStatus = null;
                                  startDate = null;
                                  endDate = null;
                                }),
                                icon: const Icon(Icons.clear),
                              ),
                              const SizedBox(width: 8),
                              const Text('Only my tasks'),
                              Switch.adaptive(
                                value: _onlyMyTasks,
                                onChanged: (v) => setState(() => _onlyMyTasks = v),
                              ),
                            ],
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),

            // Task list below filters
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No tasks found.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final t = filtered[idx];
                        final due = t['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(t['dueDate']).toLocal() : null;
                        final status = (t['status'] ?? '').toString();
                        final priority = (t['priority'] ?? '').toString();
                        final today = DateTime.now();
                        final isOverdue = due != null && due.isBefore(DateTime(today.year, today.month, today.day));
                        final isSoon = due != null && !isOverdue && due.difference(today).inDays <= 3;
                        Color dueColor = Colors.grey.shade300;
                        if (isOverdue) dueColor = Colors.red.shade100;
                        else if (isSoon) dueColor = Colors.orange.shade100;

                        Color priorityColor(String p) {
                          switch (p.toLowerCase()) {
                            case 'urgent':
                              return Colors.red.shade600;
                            case 'high':
                              return Colors.orange.shade700;
                            case 'medium':
                              return Colors.blue.shade600;
                            default:
                              return Colors.grey.shade600;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status color stripe
                                  Container(width: 6, height: 56, decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(width: 12),
                                  // Main content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                t['name'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (priority.isNotEmpty)
                                              Container(
                                                decoration: BoxDecoration(color: priorityColor(priority).withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                child: Row(children: [
                                                  Icon(Icons.flag, size: 14, color: priorityColor(priority)),
                                                  const SizedBox(width: 4),
                                                  Text(priority, style: TextStyle(color: priorityColor(priority), fontWeight: FontWeight.w600)),
                                                ]),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            if ((t['project'] ?? '').toString().isNotEmpty)
                                              Chip(avatar: const Icon(Icons.work_outline, size: 16), label: Text('${t['project']}')),
                                            if ((t['branch'] ?? '').toString().isNotEmpty)
                                              Chip(avatar: const Icon(Icons.apartment_outlined, size: 16), label: Text('${t['branch']}')),
                                            if ((t['assignTo'] ?? '').toString().isNotEmpty)
                                              Chip(avatar: const Icon(Icons.person_outline, size: 16), label: Text('${t['assignTo']}')),
                                            if (status.isNotEmpty)
                                              Chip(
                                                label: Text(status, style: const TextStyle(color: Colors.white)),
                                                backgroundColor: _statusColor(status),
                                              ),
                                          ],
                                        ),
                                        if ((t['notes'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            (t['notes'] ?? '').toString(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.black54),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Due date pill
                                  if (due != null)
                                    Container(
                                      decoration: BoxDecoration(color: dueColor, borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(isOverdue ? Icons.warning_amber_rounded : Icons.event, size: 16, color: isOverdue ? Colors.red[700] : Colors.black54),
                                          const SizedBox(width: 6),
                                          Text('${due.year}-${due.month.toString().padLeft(2,'0')}-${due.day.toString().padLeft(2,'0')}'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks App'),
        centerTitle: true,
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !isWide,
        leading: isWide
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: IconButton(
                    tooltip: _railExtended ? 'Collapse sidebar' : 'Expand sidebar',
                    icon: const Icon(Icons.view_sidebar),
                    color: Colors.white,
                    onPressed: () => setState(() => _railExtended = !_railExtended),
                  ),
                ),
              )
            : null,
        actions: [
          if (_contentIndex == 0 && _has(PermKeys.tasksEdit))
            IconButton(
              tooltip: 'Add Task',
              icon: const Icon(Icons.add_task_outlined),
              onPressed: () => showAddTaskDialog(context),
            ),
        ],
      ),
      drawer: isWide
          ? null
          : SideDrawer(
              displayName: _displayName,
              displayEmail: _displayEmail,
              isAdmin: _isAdmin,
              onSelect: (contentIdx, navIdx) {
                // Gate by view permissions similar to NavigationRail
                bool allow = true;
                switch (contentIdx) {
                  case 1:
                    allow = _has(PermKeys.projectsView);
                    break;
                  case 2:
                    allow = _has(PermKeys.personsView);
                    break;
                  case 3:
                    allow = _has(PermKeys.branchesView);
                    break;
                  case 4:
                    allow = _has(PermKeys.attendanceView);
                    break;
                  case 5:
                    allow = _has(PermKeys.leavesView);
                    break;
                  default:
                    allow = true;
                }
                if (!allow) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No permission to view this section.')));
                  return;
                }
                setState(() {
                  _contentIndex = contentIdx;
                  _selectedNavIndex = navIdx;
                });
              },
            ),
      body: isWide
          ? Row(
              children: [
                _buildNavRail(context),
                const VerticalDivider(width: 1),
                Expanded(child: _buildCenterContent()),
              ],
            )
          : _buildCenterContent(),
    );
  }
}
