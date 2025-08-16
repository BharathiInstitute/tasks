import 'package:flutter/material.dart';
import 'menu_helper.dart';
import 'permissions.dart';

class AppNavRail extends StatelessWidget {
  final bool extended;
  final int selectedIndex;
  final Set<String> allowed;
  final bool isAdmin;
  final String displayName;
  final String displayEmail;
  final void Function(int contentIndex, int navIndex) onSelect;
  final VoidCallback onLogout;

  const AppNavRail({
    super.key,
    required this.extended,
    required this.selectedIndex,
    required this.allowed,
    required this.isAdmin,
    required this.displayName,
    required this.displayEmail,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
  final items = MenuHelper.buildRailItems(allowed, isAdmin);
    return Container(
      width: extended ? 220 : 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(right: BorderSide(width: 1, color: Color(0x11000000))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
              ),
            ),
            if (extended) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (displayEmail.isNotEmpty)
                      Text(
                        displayEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (var idx = 0; idx < items.length; idx++) ...[
                  if (items[idx].label == 'Data' && (
                        isAdmin ||
                        allowed.contains(PermKeys.projectsView) ||
                        allowed.contains(PermKeys.personsView) ||
                        allowed.contains(PermKeys.branchesView)))
                    _DataRailGroup(
                      extended: extended,
                      selectedIndex: selectedIndex,
                      groupNavIndex: idx,
                      isAdmin: isAdmin,
                      allowed: allowed,
                      onSelect: onSelect,
                    )
                  else if (items[idx].label != 'Data')
                    _RailRow(
                      icon: items[idx].icon,
                      label: items[idx].label,
                      extended: extended,
                      selected: idx == selectedIndex,
                      onTap: () {
                        final it = items[idx];
                        if (it.content == null) { onLogout(); return; }
                        final target = it.content!;
                        if (target == 6 && !isAdmin) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admins only.')));
                          return;
                        }
                        if (!isAdmin && !MenuHelper.canViewContent(target, allowed, isAdmin)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No permission to view this section.')));
                          return;
                        }
                        onSelect(target, idx);
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRailGroup extends StatefulWidget {
  final bool extended;
  final int selectedIndex; // current nav index selection
  final int groupNavIndex; // index where Data group sits
  final bool isAdmin;
  final Set<String> allowed;
  final void Function(int contentIndex, int navIndex) onSelect;
  const _DataRailGroup({required this.extended, required this.selectedIndex, required this.groupNavIndex, required this.isAdmin, required this.allowed, required this.onSelect});

  @override
  State<_DataRailGroup> createState() => _DataRailGroupState();
}

class _DataRailGroupState extends State<_DataRailGroup> {
  bool _open = false;

  bool get canProjects => widget.isAdmin || widget.allowed.contains(PermKeys.projectsView);
  bool get canPersons => widget.isAdmin || widget.allowed.contains(PermKeys.personsView);
  bool get canBranches => widget.isAdmin || widget.allowed.contains(PermKeys.branchesView);

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedIndex == widget.groupNavIndex || _open;
    final theme = Theme.of(context);
  final bg = selected ? theme.colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent;
    final fg = selected ? theme.colorScheme.primary : Colors.black87;

    Widget header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.extended ? 14 : 0, vertical: 10),
            child: Row(
              mainAxisAlignment: widget.extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_copy_outlined, color: fg, size: 22),
                if (widget.extended) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Data',
                      style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0.0, // rotate chevron
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: fg, size: 20),
                  ),
                ] else ...[
                  // Collapsed rail: show a tiny indicator badge when open
                  const SizedBox(width: 0),
                  if (_open)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.circle, size: 6, color: fg),
                    ),
                ]
              ],
            ),
          ),
        ),
      ),
    );

    if (!_open) return header;
    List<Widget> children = [header];
    Widget makeChild(String label, IconData icon, int content, bool enabled) {
      return Padding(
        padding: EdgeInsets.only(left: widget.extended ? 16 : 0),
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: _RailRow(
            icon: icon,
            label: label,
            extended: widget.extended,
            selected: widget.selectedIndex != widget.groupNavIndex && false, // sub-items not tracked as primary selection
            onTap: () {
              if (!enabled) return;
              widget.onSelect(content, widget.groupNavIndex);
            },
          ),
        ),
      );
    }
    if (canProjects) children.add(makeChild('Projects', Icons.work_outline, 1, canProjects));
    if (canPersons) children.add(makeChild('Persons', Icons.person_add_alt_1_outlined, 2, canPersons));
    if (canBranches) children.add(makeChild('Branches', Icons.add_business_outlined, 3, canBranches));
  final canAnyData = canProjects || canPersons || canBranches; // same visibility grouping
  if (canAnyData) children.add(makeChild('Template Goals', Icons.flag_outlined, 12, canAnyData));
    return Column(children: children);
  }
}

class _RailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool extended;
  final bool selected;
  final VoidCallback onTap;
  const _RailRow({required this.icon, required this.label, required this.extended, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
  final bg = selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent;
    final fg = selected ? Theme.of(context).colorScheme.primary : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 10),
            child: Row(
              mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 22),
                if (extended) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
