// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'add_tasks_new.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'manage_projects.dart';
import 'manage_branches.dart';
import 'manage_persons.dart';
import 'attendance_dashboard.dart';
import 'leaves_panel.dart';
import 'role_service.dart';
import 'side_drawer.dart';
import 'permissions_admin.dart';
import 'permissions.dart';
import 'app_nav_rail.dart';
import 'attendance_correction.dart';
import 'leaves_admin_panel.dart';
import 'my_tasks_panel.dart';
import 'home.dart';
import 'practice_panel.dart';
import 'template_goals_panel.dart';

class Tasks extends StatefulWidget {
  const Tasks({super.key});
  @override
  TasksState createState() => TasksState();
}

class TasksState extends State<Tasks> {
  // Horizontal scroll sync controllers for task table (header + body)
  final ScrollController _taskHeaderHCtrl = ScrollController();
  final ScrollController _taskListHCtrl = ScrollController();
  Color _statusColor(String s) {
    final status = s.toLowerCase();
  if (status.contains('complete') || status.contains('done')) return Colors.green.shade600; // Completed
  if (status.contains('work') || status.contains('progress')) return Colors.blue.shade600; // Working
  if (status.contains('pending')) return Colors.orange.shade700; // Pending
    return Colors.grey.shade700;
  }

  String _displayName = 'User';
  String _displayEmail = '';
  bool _isAdmin = false;
  Set<String> _allowed = {};
  StreamSubscription? _userPermsSub;

  void _ensureIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      final email = (user.email ?? '').trim();
      final name = (user.displayName ?? '').trim();
      _displayName = name.isNotEmpty
          ? name
          : (email.isNotEmpty ? email.split('@').first : 'User');
      _displayEmail = email.isNotEmpty ? email : 'unknown@example.com';
  // DEBUG LOG
  // debug logging removed
  // Ensure role document exists so Firestore security rules (which read roles/{uid}) recognize admin.
  // Firestore rules previously failed because roles/{uid} was never written (ensureRoleSet was never called).
  Future.microtask(() => RoleService.ensureRoleSet(user));
    } else {
      const firstNames = ['Alex', 'Taylor', 'Jordan', 'Casey', 'Riley', 'Avery', 'Morgan', 'Quinn'];
      const lastNames = ['Smith', 'Johnson', 'Lee', 'Patel', 'Garcia', 'Brown', 'Davis', 'Miller'];
      final r = Random();
      final first = firstNames[r.nextInt(firstNames.length)];
      final last = lastNames[r.nextInt(lastNames.length)];
      final num = 1000 + r.nextInt(9000);
      _displayName = '$first $last';
      _displayEmail = '${first.toLowerCase()}.${last.toLowerCase()}$num@example.com';
  // debug logging removed
    }
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = await RoleService.fetchIsAdmin(user);
    if (mounted) setState(() => _isAdmin = isAdmin);
  // debug logging removed
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
  String? _userBranchName; // resolved branch name for current user
  List<String> _visibleProjects = []; // projects within current visible task scope (non-admin)
  // My Tasks (contentIndex = 9) specific filter state
  String? taskNameQuery; // text filter for task name on View Tasks
  String? mySelectedProject;
  String? mySelectedStatus;
  DateTime? myStartDate;
  DateTime? myEndDate;
  bool myShowBranchTasks = false; // when true and user has branchFilterView, show whole branch

  @override
  void initState() {
    super.initState();
    _ensureIdentity();
    _loadPerms();
    _subscribeUserPerms();
    fetchBranchesAndPersons();
    fetchProjects();
    _loadRole();
    _loadUserBranch();
    _taskListHCtrl.addListener(() {
      if (_taskHeaderHCtrl.hasClients &&
          _taskHeaderHCtrl.position.pixels != _taskListHCtrl.position.pixels) {
        _taskHeaderHCtrl.jumpTo(_taskListHCtrl.position.pixels);
      }
    });
  }

  Future<void> _loadUserBranch() async {
    try {
      final email = _displayEmail.toLowerCase();
      if (email.isEmpty) return;
      final persons = await _firestore.collection('persons').where('email', isEqualTo: email).limit(1).get();
      if (persons.docs.isEmpty) return;
      final data = persons.docs.first.data();
      final branchId = (data['branchId'] ?? '').toString();
      if (branchId.isEmpty) return;
      final branchDoc = await _firestore.collection('branches').doc(branchId).get();
      final name = (branchDoc.data()?['name'] ?? '').toString();
      if (name.isNotEmpty && mounted) setState(() => _userBranchName = name);
  // debug logging removed
    } catch (_) {/* ignore */}
  }

  bool _isTaskMine(Map<String,dynamic> t) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final assigneeUid = (t['assigneeUid'] ?? '').toString();
    final assignTo = (t['assignTo'] ?? '').toString();
    final email = (t['assigneeEmail'] ?? '').toString();
  final createdBy = (t['createdBy'] ?? '').toString();
  return (uid != null && (assigneeUid == uid || createdBy == uid)) ||
        (assignTo.isNotEmpty && assignTo.toLowerCase() == _displayName.toLowerCase()) ||
        (_displayEmail.isNotEmpty && email.toLowerCase() == _displayEmail.toLowerCase());
  }

  bool _canEditTask(Map<String,dynamic> t) {
  if (!_has(PermKeys.tasksEdit)) return false;
  if (_isAdmin) return true;
  // On global Tasks screen restrict non-admin edits to own tasks only
  return _isTaskMine(t);
  }

  bool _canDeleteTask(Map<String,dynamic> t) {
  if (!_has(PermKeys.tasksDelete)) return false;
  if (_isAdmin) return true;
  // Only own tasks deletable here
  return _isTaskMine(t);
  }

  void _subscribeUserPerms() {
    final email = _displayEmail.trim().toLowerCase();
    if (email.isEmpty) return;
    _userPermsSub?.cancel();
    _userPermsSub = FirebaseFirestore.instance
        .collection('userPerms')
        .doc(email)
        .snapshots()
        .listen((snap) async {
      if (snap.exists) {
        final data = snap.data();
        final list = (data != null && data['allowed'] is List)
            ? List<String>.from(data['allowed']).toSet()
            : <String>{};
        if (mounted) setState(() => _allowed = list);
      } else {
        final role = await RoleService.fetchRole(FirebaseAuth.instance.currentUser) ?? 'employee';
        final baseline = await PermissionsService.fetchAllowedKeysForRole(role);
        if (mounted) setState(() => _allowed = baseline);
      }
    });
  }

  Future<void> _loadPerms() async {
  // debug logging removed
    try {
      final email = (_displayEmail).trim();
      final explicit = await PermissionsService.fetchExplicitKeysForEmailOrNull(email);
      if (explicit != null) {
        if (mounted) setState(() => _allowed = explicit);
  // debug logging removed
      } else {
        final role = await RoleService.fetchRole(FirebaseAuth.instance.currentUser) ?? 'employee';
        final baseline = await PermissionsService.fetchAllowedKeysForRole(role);
        if (mounted) setState(() => _allowed = baseline);
  // debug logging removed
      }
    } finally {
  // debug logging removed
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
  int _selectedNavIndex = 0; // menu index (Home initially at 0)
  int _contentIndex = 10; // default to Home dashboard

  Widget _buildCenterContent() {
    switch (_contentIndex) {
      case 10:
        return const EmployeeHomePanel();
      case 11:
        return const PracticePanel();
      case 12:
  return TemplateGoalsPanel(allowed: _allowed, isAdmin: _isAdmin);
      case 0:
        return _buildTaskContent();
      case 1:
        return const ManageProjectsPage();
      case 2:
        return const ManagePersonsPage();
      case 3:
        return const ManageBranchesPage();
      case 4:
        return const AttendancePanel();
      case 5:
        return Padding(padding: const EdgeInsets.all(16.0), child: LeavesPanel(allowed: _allowed, isAdmin: _isAdmin));
      case 6:
        if (!_isAdmin) {
          return const Center(child: Text('You do not have access to Permissions. Admins only.'));
        }
        return const Padding(padding: EdgeInsets.all(16.0), child: PermissionsAdminPanel());
      case 7:
        if (!_isAdmin) {
          return const Center(child: Text('Admins only.'));
        }
        return const AttendanceCorrectionPage();
      case 8:
        if(!_isAdmin && !_has(PermKeys.leavesApprove)){
          return const Center(child: Text('No permission to manage leave approvals.'));
        }
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: LeavesAdminPanel(allowed: _allowed, isAdmin: _isAdmin),
        );
      case 9:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MyTasksPanel(
            allowed: _allowed,
            selectedProject: mySelectedProject,
            selectedStatus: mySelectedStatus,
            startDate: myStartDate,
            endDate: myEndDate,
            showBranchTasks: myShowBranchTasks && _has(PermKeys.branchFilterView),
            userBranchName: _userBranchName,
          ),
        );
      default:
        return _buildTaskContent();
    }
  }

  Widget _buildNavRail(BuildContext context) {
    return AppNavRail(
      extended: _railExtended,
      selectedIndex: _selectedNavIndex,
      allowed: _allowed,
      isAdmin: _isAdmin,
      displayName: _displayName,
      displayEmail: _displayEmail,
      onSelect: (contentIdx, navIdx) {
        if (contentIdx == -1) {
          // Open a simple chooser for Projects / Persons / Branches
          showModalBottomSheet(
            context: context,
            builder: (ctx) {
              Widget entry(String label, int targetIndex, {required bool enabled, IconData icon = Icons.circle}) {
                return ListTile(
                  enabled: enabled,
                  leading: Icon(icon, size: 20),
                  title: Text(label),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!enabled) return;
                    setState(() {
                      _contentIndex = targetIndex;
                      _selectedNavIndex = navIdx; // keep Data selected or optionally change later
                    });
                  },
                );
              }
              final canProjects = _isAdmin || _allowed.contains(PermKeys.projectsView);
              final canPersons = _isAdmin || _allowed.contains(PermKeys.personsView);
              final canBranches = _isAdmin || _allowed.contains(PermKeys.branchesView);
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    entry('Projects', 1, enabled: canProjects, icon: Icons.work_outline),
                    entry('Persons', 2, enabled: canPersons, icon: Icons.person_add_alt_1_outlined),
                    entry('Branches', 3, enabled: canBranches, icon: Icons.add_business_outlined),
                    entry('Template Goals', 12, enabled: (canProjects || canPersons || canBranches), icon: Icons.flag_outlined),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
          return;
        }
        setState(() {
          _contentIndex = contentIdx;
          _selectedNavIndex = navIdx;
        });
      },
      onLogout: () async {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
    );
  }

  Widget _buildTaskContent() {
  // Permissions removed – always show tasks (filtered to user ownership below)
  // Current user accessed indirectly within helper methods; no local uid needed.
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('tasks').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // silently ignore stream errors in UI (could show a message if desired)
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No tasks found.'));
        }
    List<Map<String, dynamic>> tasks = snapshot.data!.docs
      .map((doc) => doc.data() as Map<String, dynamic>)
      .where(_isTaskMine) // always restrict to user-owned/assigned tasks
      .toList();

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
          final name = (task['name'] ?? '').toString().toLowerCase();
          final nameMatch = taskNameQuery == null || taskNameQuery!.trim().isEmpty || name.contains(taskNameQuery!.trim().toLowerCase());
          return projectMatch && branchMatch && personMatch && statusMatch && dateMatch && nameMatch;
        }).toList();
  // debug logging removed

        final minTableWidth = 1100.0; // ensure space for all columns in one line
        return LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth < minTableWidth ? minTableWidth : constraints.maxWidth;

            final canViewBranches = _has(PermKeys.branchFilterView);
            Widget headerRow() => Card(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  elevation: 1,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const _HeaderCell(label: 'Task', flex: 2),
                        const _HeaderCell(label: 'Project'),
                        if (canViewBranches) const _HeaderCell(label: 'Branch'),
                        const _HeaderCell(label: 'Assignee'),
                        const _HeaderCell(label: 'Status'),
                        const _HeaderCell(label: 'Priority'),
                        const _HeaderCell(label: 'Due Date'),
                        const _HeaderCell(label: 'Notes', flex: 2, align: TextAlign.left),
                      ],
                    ),
                  ),
                );

            Widget buildRow(Map<String, dynamic> t) {
              final status = (t['status'] ?? '').toString();
              final priority = (t['priority'] ?? '').toString();
              final due = t['dueDate'] != null ? DateTime.fromMillisecondsSinceEpoch(t['dueDate']).toLocal() : null;
              final today = DateTime.now();
              final isOverdue = due != null && due.isBefore(DateTime(today.year, today.month, today.day));
              final isSoon = due != null && !isOverdue && due.difference(today).inDays <= 3;
              Color dueColor = Colors.black87;
              if (isOverdue) {
                dueColor = Colors.red.shade700;
              } else if (isSoon) {
                dueColor = Colors.orange.shade700;
              }

              Color priorityColor(String p) {
                switch (p.toLowerCase()) {
                  case 'urgent':
                    return Colors.red.shade600;
                  case 'medium':
                    return Colors.orange.shade700; // medium now orange emphasis
                  case 'low':
                    return Colors.blue.shade600; // low calmer blue
                  default:
                    return Colors.grey.shade600;
                }
              }

              Widget statusPill() => status.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    );

              Widget priorityPill() => priority.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor(priority).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, size: 12, color: priorityColor(priority)),
                          const SizedBox(width: 3),
                          Text(priority, style: TextStyle(color: priorityColor(priority), fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );

              final dueStr = due == null ? '' : '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';

        return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                elevation: 0.7,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
          onTap: _has(PermKeys.tasksView) && _canEditTask(t)
            ? () => showAddTaskDialog(context, existing: t, allowed: _allowed)
            : null,
          onLongPress: _canDeleteTask(t)
            ? () async {
                          final id = (t['id'] ?? '').toString();
                          if (id.isEmpty) return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Delete Task'),
                              content: const Text('Delete this task? This cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await FirebaseFirestore.instance.collection('tasks').doc(id).delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted')));
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                              }
                            }
                          }
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      _RowCell(text: (t['name'] ?? '').toString(), flex: 2, bold: true),
                      _RowCell(text: (t['project'] ?? '').toString()),
                      if (canViewBranches) _RowCell(text: (t['branch'] ?? '').toString()),
                      _RowCell(text: (t['assignTo'] ?? '').toString()),
                      Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: statusPill())),
                      Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: priorityPill())),
                      _RowCell(text: dueStr, color: dueColor),
                      _RowCell(text: (t['notes'] ?? '').toString(), flex: 2, maxLines: 1, ellipsis: true, color: Colors.black54),
                    ]),
                  ),
                ),
              );
            }

            final list = filtered.map(buildRow).toList();
            // Derive visible projects for non-admin filter dropdowns
            if (!_isAdmin) {
              final projSet = <String>{};
              for (final t in filtered) {
                final p = (t['project'] ?? '').toString();
                if (p.isNotEmpty) projSet.add(p);
              }
              final derived = projSet.toList()..sort();
              if (mounted && derived.toString() != _visibleProjects.toString()) {
                WidgetsBinding.instance.addPostFrameCallback((_){
                  if (mounted) setState(()=> _visibleProjects = derived);
                });
              }
            }

            return Column(
              children: [
                SingleChildScrollView(
                  controller: _taskHeaderHCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(width: contentWidth, child: headerRow()),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No tasks found.'))
                      : Scrollbar(
                          controller: _taskListHCtrl,
                          thumbVisibility: true,
                          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _taskListHCtrl,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                              width: contentWidth,
                              child: ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (c, i) => list[i],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
  title: Text(_contentIndex == 9 ? 'My Tasks' : 'Tasks'),
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
                    color: Colors.white.withValues(alpha: 0.12),
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
          if (_isAdmin && _contentIndex == 0 && _has(PermKeys.tasksView))
            IconButton(
              tooltip: 'Filters',
              icon: const Icon(Icons.filter_alt_outlined),
              onPressed: _openTaskFilters,
            ),
          if (_contentIndex == 9 && _has(PermKeys.tasksView))
            IconButton(
              tooltip: 'My Task Filters',
              icon: const Icon(Icons.filter_list),
              onPressed: _openMyTaskFilters,
            ),
          // Removed Add Task icon for View Tasks (use FAB)
        ],
      ),
      drawer: isWide
          ? null
          : SideDrawer(
              displayName: _displayName,
              displayEmail: _displayEmail,
              isAdmin: _isAdmin,
              allowed: _allowed,
              onSelect: (contentIdx, navIdx) {
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
                    allow = true; // attendance always allowed
                    break;
                  case 5:
                    allow = true; // leaves always allowed
                    break;
                  case 9:
                    allow = true; // My Tasks always allowed
                    break;
                  default:
                    allow = true;
                }
                if (contentIdx == 6 && !_isAdmin) {
                  allow = false;
                }
                if (contentIdx == 7 && !_isAdmin) {
                  allow = false;
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
  floatingActionButton: (((_isAdmin && _contentIndex == 0) || _contentIndex == 9) && _has(PermKeys.tasksAdd))
          ? FloatingActionButton.extended(
              heroTag: 'addTaskFab',
              onPressed: () => showAddTaskDialog(
                context,
                allowed: _allowed,
                enforceSelf: _contentIndex == 9, // only restrict when on My Tasks
                selfName: _displayName,
                selfBranch: _userBranchName,
                selfEmail: _displayEmail,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _userPermsSub?.cancel();
  _taskHeaderHCtrl.dispose();
  _taskListHCtrl.dispose();
    super.dispose();
  }

  void _openTaskFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final compact = MediaQuery.of(ctx).size.width < 600;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              Widget dateButton() => OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() { startDate = picked.start; endDate = picked.end; });
                    setSheet(() {});
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(startDate == null && endDate == null
                    ? 'Any date'
                    : '${startDate?.year}-${startDate?.month.toString().padLeft(2, '0')}-${startDate?.day.toString().padLeft(2, '0')} -> ${endDate?.year}-${endDate?.month.toString().padLeft(2, '0')}-${endDate?.day.toString().padLeft(2, '0')}'),
              );

              final canViewBranches = _has(PermKeys.branchFilterView);
              final nameController = TextEditingController(text: taskNameQuery ?? '');
              final projectItems = _isAdmin ? allProjects : _visibleProjects;
              final branchItems = _isAdmin
                  ? allBranches
                  : (_userBranchName != null && _userBranchName!.isNotEmpty
                      ? [_userBranchName!]
                      : <String>[]);

              List<Widget> buildRows({required bool compact}) {
                if (!compact) {
                  return [
                    Row(children: [
                      Expanded(child: _dd(label: 'Project', value: selectedProject, items: projectItems, icon: Icons.work_outline, onChanged: (v){ setState(()=>selectedProject=v); setSheet((){}); })),
                      if (canViewBranches) const SizedBox(width: 12),
                      if (canViewBranches) Expanded(child: _dd(label: 'Branch', value: selectedBranch, items: branchItems, icon: Icons.category_outlined, onChanged: (v){ setState(()=>selectedBranch=v); setSheet((){}); })),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _dd(label: 'Assignee', value: selectedPerson, items: allPersons, icon: Icons.person_outline, onChanged: (v){ setState(()=>selectedPerson=v); setSheet((){}); })),
                      const SizedBox(width: 12),
                      Expanded(child: _dd(label: 'Status', value: selectedStatus, items: _statusList(), icon: Icons.flag_outlined, onChanged: (v){ setState(()=>selectedStatus=v); setSheet((){}); })),
                    ]),
                    const SizedBox(height: 12),
                  ];
                } else {
                  return [
                    _dd(label: 'Project', value: selectedProject, items: projectItems, icon: Icons.work_outline, onChanged: (v){ setState(()=>selectedProject=v); setSheet((){}); }),
                    if (canViewBranches) const SizedBox(height: 8),
                    if (canViewBranches) _dd(label: 'Branch', value: selectedBranch, items: branchItems, icon: Icons.category_outlined, onChanged: (v){ setState(()=>selectedBranch=v); setSheet((){}); }),
                    const SizedBox(height: 8),
                    _dd(label: 'Assignee', value: selectedPerson, items: allPersons, icon: Icons.person_outline, onChanged: (v){ setState(()=>selectedPerson=v); setSheet((){}); }),
                    const SizedBox(height: 8),
                    _dd(label: 'Status', value: selectedStatus, items: _statusList(), icon: Icons.flag_outlined, onChanged: (v){ setState(()=>selectedStatus=v); setSheet((){}); }),
                    const SizedBox(height: 12),
                  ];
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.filter_alt_outlined),
                      const SizedBox(width: 8),
                      const Text('Task Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(onPressed: ()=> Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                    ]),
                    const SizedBox(height: 12),
                    ...buildRows(compact: compact),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Task name contains', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                      onChanged: (v){ setState(()=> taskNameQuery = v); setSheet((){}); },
                    ),
                    const SizedBox(height: 12),
                    Row(children:[
                      Expanded(child: dateButton()),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          setState(() {
                            selectedProject = null;
                            selectedBranch = null;
                            selectedPerson = null;
                            selectedStatus = null;
                            startDate = null;
                            endDate = null;
                            _onlyMyTasks = false;
                            taskNameQuery = null;
                          });
                          setSheet(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                      if (_isAdmin) const SizedBox(width: 8),
                      if (_isAdmin) const Text('Only mine'),
                      if (_isAdmin) Switch.adaptive(value: _onlyMyTasks, onChanged: (v){ setState(()=> _onlyMyTasks = v); setSheet((){}); }),
                    ]),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: ()=> Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openMyTaskFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final compact = MediaQuery.of(ctx).size.width < 600;
        final projectItems = allProjects;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              Widget dateButton() => OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      myStartDate = picked.start;
                      myEndDate = picked.end;
                    });
                    setSheet(() {});
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(myStartDate == null && myEndDate == null
                    ? 'Any date'
                    : '${myStartDate?.year}-${myStartDate?.month.toString().padLeft(2, '0')}-${myStartDate?.day.toString().padLeft(2, '0')} -> ${myEndDate?.year}-${myEndDate?.month.toString().padLeft(2, '0')}-${myEndDate?.day.toString().padLeft(2, '0')}'),
              );

              List<Widget> large() => [
                    Row(children: [
                      Expanded(child: _dd(label: 'Project', value: mySelectedProject, items: projectItems, icon: Icons.work_outline, onChanged: (v) { setState(() => mySelectedProject = v); setSheet(() {}); })),
                      const SizedBox(width: 12),
                      Expanded(child: _dd(label: 'Status', value: mySelectedStatus, items: _statusList(), icon: Icons.flag_outlined, onChanged: (v) { setState(() => mySelectedStatus = v); setSheet(() {}); })),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: dateButton()),
                      const SizedBox(width: 12),
                      if (_has(PermKeys.branchFilterView) && (_userBranchName?.isNotEmpty ?? false)) const Text('Branch'),
                      if (_has(PermKeys.branchFilterView) && (_userBranchName?.isNotEmpty ?? false)) Switch.adaptive(
                        value: myShowBranchTasks,
                        onChanged: (v) { setState(() => myShowBranchTasks = v); setSheet(() {}); },
                      ),
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          setState(() {
                            mySelectedProject = null;
                            mySelectedStatus = null;
                            myStartDate = null;
                            myEndDate = null;
                            myShowBranchTasks = false;
                          });
                          setSheet(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ]),
                  ];

              List<Widget> small() => [
                    _dd(label: 'Project', value: mySelectedProject, items: projectItems, icon: Icons.work_outline, onChanged: (v) { setState(() => mySelectedProject = v); setSheet(() {}); }),
                    const SizedBox(height: 8),
                    _dd(label: 'Status', value: mySelectedStatus, items: _statusList(), icon: Icons.flag_outlined, onChanged: (v) { setState(() => mySelectedStatus = v); setSheet(() {}); }),
                    const SizedBox(height: 8),
                    dateButton(),
                    Row(children: [
                      if (_has(PermKeys.branchFilterView) && (_userBranchName?.isNotEmpty ?? false)) const Text('Branch'),
                      if (_has(PermKeys.branchFilterView) && (_userBranchName?.isNotEmpty ?? false)) Switch.adaptive(
                        value: myShowBranchTasks,
                        onChanged: (v) { setState(() => myShowBranchTasks = v); setSheet(() {}); },
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          setState(() {
                            mySelectedProject = null;
                            mySelectedStatus = null;
                            myStartDate = null;
                            myEndDate = null;
                            myShowBranchTasks = false;
                          });
                          setSheet(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ])
                  ];

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.filter_list),
                        const SizedBox(width: 8),
                        const Text('My Task Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                      ]),
                      const SizedBox(height: 12),
                      ...(compact ? small() : large()),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<String> _statusList() {
    final base = <String>{'Working','Pending','Completed'};
    if (selectedStatus != null) base.add(selectedStatus!);
    return base.toList();
  }

  Widget _dd({required String label, required String? value, required List<String> items, required IconData icon, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon)),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        ...items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
      ],
      onChanged: onChanged,
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final TextAlign align;
  const _HeaderCell({required this.label, this.flex = 1, this.align = TextAlign.left});
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.blueGrey.shade800,
          letterSpacing: .4,
        );
    Alignment alignment;
    switch (align) {
      case TextAlign.right:
        alignment = Alignment.centerRight;
        break;
      case TextAlign.center:
        alignment = Alignment.center;
        break;
      default:
        alignment = Alignment.centerLeft;
    }
    return Expanded(
      flex: flex,
      child: Align(alignment: alignment, child: Text(label, style: style)),
    );
  }
}

class _RowCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;
  final int maxLines;
  final bool ellipsis;
  const _RowCell({required this.text, this.flex = 1, this.bold = false, this.color, this.maxLines = 1, this.ellipsis = false});
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.w400, fontSize: 13, color: color ?? Colors.black87);
    return Expanded(
      flex: flex,
      child: Text(text, maxLines: maxLines, overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.visible, style: style),
    );
  }
}
