// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_tasks_new.dart';
import 'permissions.dart';

/// My Tasks panel – table layout similar to main Tasks screen but only shows the
/// current user's tasks. Branch column is shown only if branchFilterView is allowed.
class MyTasksPanel extends StatefulWidget {
  final Set<String> allowed;
  final String? selectedProject;
  final String? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool showBranchTasks; // if true and branch permission, include all tasks in user's branch
  final String? userBranchName;
  const MyTasksPanel({super.key, required this.allowed, this.selectedProject, this.selectedStatus, this.startDate, this.endDate, this.showBranchTasks=false, this.userBranchName});

  @override
  State<MyTasksPanel> createState() => _MyTasksPanelState();
}

class _MyTasksPanelState extends State<MyTasksPanel> {
  final _fs = FirebaseFirestore.instance;
  late final String _email;
  late final String _name;
  late final String? _uid;
  final ScrollController _headerCtrl = ScrollController();
  final ScrollController _bodyCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    final rawEmail = (user?.email ?? '').trim();
    _email = rawEmail.toLowerCase();
    final rawName = (user?.displayName ?? '').trim();
    _name = rawName.isNotEmpty
        ? rawName
        : (rawEmail.isNotEmpty ? rawEmail.split('@').first : 'User');
    _bodyCtrl.addListener(() {
      if (_headerCtrl.hasClients && _headerCtrl.position.pixels != _bodyCtrl.position.pixels) {
        _headerCtrl.jumpTo(_bodyCtrl.position.pixels);
      }
    });
  }

  bool _isMine(Map<String, dynamic> t) {
    final assigneeUid = (t['assigneeUid'] ?? '').toString();
    final assignTo = (t['assignTo'] ?? '').toString();
    final assigneeEmail = (t['assigneeEmail'] ?? '').toString().toLowerCase();
    if (_uid != null && assigneeUid == _uid) return true;
    if (_email.isNotEmpty && assigneeEmail == _email) return true;
    if (assignTo.isNotEmpty && assignTo.toLowerCase() == _name.toLowerCase()) return true;
    return false;
  }

  Color _statusColor(String s) {
    final status = s.toLowerCase();
    if (status.contains('completed') || status.contains('complete') || status.contains('done')) return Colors.green.shade600;
    if (status.contains('working')) return Colors.blue.shade600;
    if (status.contains('pending')) return Colors.orange.shade700;
    return Colors.grey.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _fs.collection('tasks').snapshots(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        List<QueryDocumentSnapshot> docs = (s.data?.docs ?? []);
        // Base filter: own tasks or branch tasks if toggled and allowed
        docs = docs.where((d){
          final t = d.data() as Map<String,dynamic>;
          final mine = _isMine(t);
          if (mine) return true;
          if (widget.showBranchTasks && widget.allowed.contains(PermKeys.branchFilterView)) {
            final branch = (t['branch'] ?? '').toString();
            if (widget.userBranchName != null && widget.userBranchName!.isNotEmpty && branch == widget.userBranchName) {
              return true;
            }
          }
          return false;
        }).toList();

        // Additional filters: project, status, date range
        docs = docs.where((d){
          final t = d.data() as Map<String,dynamic>;
          if (widget.selectedProject != null && (t['project'] ?? '') != widget.selectedProject) return false;
          if (widget.selectedStatus != null && (t['status'] ?? '') != widget.selectedStatus) return false;
          if (widget.startDate != null || widget.endDate != null) {
            int? ms;
            if (t['dueDate'] is int) {
              ms = t['dueDate'];
            } else if (t['date'] is int) {
              ms = t['date'];
            }
            if (ms == null) return false;
            final dt = DateTime.fromMillisecondsSinceEpoch(ms);
            if (widget.startDate != null && dt.isBefore(widget.startDate!.subtract(const Duration(days:1)))) return false;
            if (widget.endDate != null && dt.isAfter(widget.endDate!.add(const Duration(days:1)))) return false;
          }
          return true;
        }).toList();
        if (docs.isEmpty) {
          return const Center(child: Text('No tasks assigned to you yet.'));
        }

  final canEdit = widget.allowed.contains(PermKeys.tasksEdit);
  final canDelete = widget.allowed.contains(PermKeys.tasksDelete);
        final showBranch = widget.allowed.contains(PermKeys.branchFilterView);
        final minWidth = 1100.0;

        Widget header() => Card(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              elevation: 1,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const _HeaderCell(label: 'Task', flex: 2),
                  const _HeaderCell(label: 'Project'),
                  if (showBranch) const _HeaderCell(label: 'Branch'),
                  const _HeaderCell(label: 'Assignee'),
                  const _HeaderCell(label: 'Status'),
                  const _HeaderCell(label: 'Priority'),
                  const _HeaderCell(label: 'Due Date'),
                  const _HeaderCell(label: 'Notes', flex: 2),
                ]),
              ),
            );

        List<Widget> rows() {
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

          return docs.map((d) {
            final t = d.data() as Map<String, dynamic>;
            final status = (t['status'] ?? '').toString();
            final priority = (t['priority'] ?? '').toString();
            final due = t['dueDate'] is int ? DateTime.fromMillisecondsSinceEpoch(t['dueDate']) : null;
            final today = DateTime.now();
            final isOverdue = due != null && due.isBefore(DateTime(today.year, today.month, today.day));
            final isSoon = due != null && !isOverdue && due.difference(today).inDays <= 3;
            Color dueColor = Colors.black87;
            if (isOverdue) {
              dueColor = Colors.red.shade700;
            } else if (isSoon) {
              dueColor = Colors.orange.shade700;
            }
            final dueStr = due == null ? '' : '${due.year}-${due.month.toString().padLeft(2,'0')}-${due.day.toString().padLeft(2,'0')}';

            Widget statusPill() => status.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _statusColor(status), borderRadius: BorderRadius.circular(14)),
                    child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  );
            Widget priorityPill() => priority.isEmpty
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: priorityColor(priority).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flag, size: 12, color: priorityColor(priority)),
                      const SizedBox(width: 3),
                      Text(priority, style: TextStyle(color: priorityColor(priority), fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  );

            bool canEditThis(Map<String,dynamic> t){
              if (!canEdit) return false;
              return _isMine(t); // branch toggle does NOT expand edit rights
            }
            bool canDeleteThis(Map<String,dynamic> t){
              if (!canDelete) return false;
              return _isMine(t); // branch toggle does NOT expand delete rights
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              elevation: .7,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: canEditThis(t)
                    ? () => showAddTaskDialog(
                          context,
                          existing: t,
                          allowed: widget.allowed,
                          enforceSelf: true, // hide Section & Assignee in My Tasks
                          selfName: _name,
                          selfBranch: widget.userBranchName,
                          selfEmail: _email,
                        )
                    : null,
                onLongPress: canDeleteThis(t) ? () async {
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
                } : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    _RowCell(text: (t['name'] ?? '').toString(), flex: 2, bold: true),
                    _RowCell(text: (t['project'] ?? '').toString()),
                    if (showBranch) _RowCell(text: (t['branch'] ?? '').toString()),
                    _RowCell(text: (t['assignTo'] ?? '').toString()),
                    Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: statusPill())),
                    Expanded(flex: 1, child: Align(alignment: Alignment.centerLeft, child: priorityPill())),
                    _RowCell(text: dueStr, color: dueColor),
                    _RowCell(text: (t['notes'] ?? '').toString(), flex: 2, maxLines: 1, ellipsis: true, color: Colors.black54),
                  ]),
                ),
              ),
            );
          }).toList();
        }

        return LayoutBuilder(
          builder: (context, cons) {
            final width = cons.maxWidth < minWidth ? minWidth : cons.maxWidth;
            final list = rows();
            return Column(
              children: [
                SingleChildScrollView(
                  controller: _headerCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(width: width, child: header()),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _bodyCtrl,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _bodyCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: width,
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
}

class _HeaderCell extends StatelessWidget {
  final String label; 
  final int flex; 
  const _HeaderCell({required this.label, this.flex = 1});
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade800, letterSpacing: .4);
    return Expanded(flex:flex, child: Align(alignment: Alignment.centerLeft, child: Text(label, style: style)));
  }
}

class _RowCell extends StatelessWidget {
  final String text; final int flex; final bool bold; final Color? color; final int maxLines; final bool ellipsis; const _RowCell({required this.text, this.flex=1, this.bold=false, this.color, this.maxLines=1, this.ellipsis=false});
  @override
  Widget build(BuildContext context){
    final style = TextStyle(fontWeight: bold?FontWeight.w600:FontWeight.w400, fontSize:13, color: color??Colors.black87);
    return Expanded(flex:flex, child: Text(text, maxLines:maxLines, overflow: ellipsis?TextOverflow.ellipsis:TextOverflow.visible, style: style));
  }
}
