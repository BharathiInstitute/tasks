import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'responsive.dart';
import 'package:geolocator/geolocator.dart';
// removed: math import (demo data generator deleted)
import 'role_service.dart';

class AttendancePanel extends StatefulWidget {
  const AttendancePanel({super.key});

  @override
  State<AttendancePanel> createState() => _AttendancePanelState();
}

class _AttendancePanelState extends State<AttendancePanel> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;


  DateTime _selectedDay = DateTime.now();
  bool _busy = false;
  String get _uid => _auth.currentUser?.uid ?? 'anon';
  String get _dateKey {
    final d = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }
  String get _attDocId => "${_uid}_$_dateKey";
  DocumentReference<Map<String, dynamic>> get _attDoc => _firestore.collection('attendance').doc(_attDocId);
  Query<Map<String, dynamic>> get _punchesQuery => _attDoc.collection('punches').orderBy('at');
  static const _officeLat = 17.457853;
  static const _officeLng = 78.422442;
  static const _officeRadiusMeters = 300.0;

  Future<({double? distance, bool? inside})> _locStatus() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        return (distance: null, inside: null);
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, _officeLat, _officeLng);
      final inside = dist <= _officeRadiusMeters;
      return (distance: dist, inside: inside);
    } catch (_) {
      return (distance: null, inside: null);
    }
  }

  Future<void> _clockIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ensureSignedIn();
    final doc = _attDoc;
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'uid': _uid,
        'dateKey': _dateKey,
        'graceMinutes': 10,
        'shiftStart': '09:30',
        'shiftEnd': '18:00',
        'site': 'Hyderabad',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    final last = await _attDoc.collection('punches').orderBy('at', descending: true).limit(1).get();
    final lastType = last.docs.isNotEmpty ? (last.docs.first.data()['type'] as String? ?? '') : '';
    if (lastType == 'in') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already clocked in. Clock out first.')));
      }
      return;
    }
    final ls = await _locStatus();
    final nowTs = Timestamp.now();
    await _attDoc.collection('punches').add({
      'type': 'in',
      'at': nowTs,
      'insideOffice': ls.inside,
      'distanceMeters': ls.distance,
      'officeLat': _officeLat,
      'officeLng': _officeLng,
    });
    await doc.set({ 'updatedAt': FieldValue.serverTimestamp() }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clocked in')));
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clock in: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clockOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ensureSignedIn();
    final doc = _attDoc;
    final snap = await doc.get();
    if (!snap.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clock in first')));
      }
      return;
    }
    final last = await _attDoc.collection('punches').orderBy('at', descending: true).limit(1).get();
    final lastType = last.docs.isNotEmpty ? (last.docs.first.data()['type'] as String? ?? '') : '';
    if (lastType != 'in') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clock in first')));
      }
      return;
    }
    final ls = await _locStatus();
    final nowTs = Timestamp.now();
    await _attDoc.collection('punches').add({
      'type': 'out',
      'at': nowTs,
      'insideOffice': ls.inside,
      'distanceMeters': ls.distance,
      'officeLat': _officeLat,
      'officeLng': _officeLng,
    });
    await doc.set({ 'updatedAt': FieldValue.serverTimestamp() }, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clocked out')));
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clock out: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<void> _signInTest() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      await RoleService.ensureRoleSet(_auth.currentUser!);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactWidth(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row (simplified)
              Row(
                children: [
                  Text('Workspace', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Chip(label: const Text('Private Project'), backgroundColor: Colors.amber.shade100),
                  const Spacer(),
                  // Month total summary replaces demo button
                  _monthlyTotalBar(),
                  const SizedBox(width: 8),
                  FutureBuilder<bool>(
                    future: RoleService.fetchIsAdmin(_auth.currentUser),
                    builder: (context, snap) => Container(
                      decoration: BoxDecoration(color: Colors.indigo.shade50, border: Border.all(color: Colors.indigo.shade200), borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text((snap.data ?? false) ? 'Admin' : 'Employee'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_auth.currentUser == null)
                    OutlinedButton(
                      onPressed: _signInTest,
                      child: const Text('Sign in (test)'),
                    )
                  else
                    OutlinedButton(
                      onPressed: _signOut,
                      child: const Text('Sign out'),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Text('Signed in as:'),
                      const SizedBox(width: 6),
                      Text(
                        _auth.currentUser == null
                            ? 'Anon'
                            : (_auth.currentUser!.isAnonymous
                                ? 'Anon'
                                : (_auth.currentUser!.email ?? _auth.currentUser!.displayName ?? 'User')),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Day selector removed
              const SizedBox(height: 12),

              // Responsive grid using Wrap
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _card(
                    width: compact ? double.infinity : 420,
                    child: _myShiftCard(),
                  ),
                  // Leave request and history moved to Leaves screen
                  // Balances & Holidays moved to Leaves panel
                ],
              ),

              const SizedBox(height: 16),
              // Today — Punches as full-width panel
              _card(
                width: double.infinity,
                child: _todayPunchesCard(),
              ),

              const SizedBox(height: 16),
              // Recent days — grouped by date (last 30 days)
              _card(
                width: double.infinity,
                child: _recentDaysPanel(),
              ),

              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Stage 1 preview • Mobile-responsive • In-memory demo (Firebase)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, double? width}) {
    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black12)),
        elevation: 0,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  Widget _myShiftCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _punchesQuery.snapshots(),
      builder: (context, psnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _attDoc.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final site = (data['site'] ?? 'Hyderabad').toString();
            final start = (data['shiftStart'] ?? '09:30').toString();
            final end = (data['shiftEnd'] ?? '18:00').toString();
            final punches = psnap.data?.docs ?? [];
            String lastType = '';
            DateTime? lastInAt;
            if (punches.isNotEmpty) {
              final last = punches.last.data();
              lastType = (last['type'] ?? '').toString();
              if (lastType == 'in') {
                lastInAt = (last['at'] as Timestamp?)?.toDate();
              }
            }
            final canIn = lastType != 'in';
            final canOut = lastType == 'in';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('My Shift (${_isToday(_selectedDay) ? 'Today' : _fmtDateOnly(_selectedDay)})', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: const Text('Grace 10 min'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _kv('Site', site),
                _kv('Start', start),
                _kv('End', end),
                const SizedBox(height: 8),
                Row(children: [
                  ElevatedButton(
                    onPressed: canIn ? _clockIn : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
                    child: const Text('Clock In'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: canOut ? _clockOut : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade300, foregroundColor: Colors.white),
                    child: const Text('Clock Out'),
                  ),
                ]),
                if (lastInAt != null) Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('Last clock in: ${_fmtTime(lastInAt)}'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _todayPunchesCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _punchesQuery.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final events = docs.map((d) => d.data()).toList();
        // Build pairs with event metadata to access insideOffice/distance
        final pairs = <Map<String, dynamic>>[];
        Map<String, dynamic>? pendingInEvent;
        for (final e in events) {
          final type = (e['type'] ?? '').toString();
          final at = (e['at'] as Timestamp?)?.toDate();
          if (type == 'in') {
            pendingInEvent = {...e, 'at': at};
          } else if (type == 'out') {
            final outEvent = {...e, 'at': at};
            pairs.add({
              'in': (pendingInEvent?['at'] as DateTime?),
              'out': at,
              'inEvent': pendingInEvent,
              'outEvent': outEvent,
            });
            pendingInEvent = null;
          }
        }
        if (pendingInEvent != null) {
          pairs.add({'in': (pendingInEvent['at'] as DateTime?), 'out': null, 'inEvent': pendingInEvent, 'outEvent': null});
        }

        Duration total = Duration.zero;
        for (final p in pairs) {
          final i = p['in'];
          final o = p['out'];
          if (i != null && o != null) {
            total += o.difference(i);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_isToday(_selectedDay) ? 'Today' : _fmtDateOnly(_selectedDay)} — Punches', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Divider(),
            if (events.isEmpty) const Text('No punches yet.') else ...[
              ...pairs.map((p) {
                final DateTime? i = p['in'] as DateTime?;
                final DateTime? o = p['out'] as DateTime?;
                final dur = (i != null && o != null) ? _fmtDuration(o.difference(i)) : 'Open';
                final Map<String, dynamic>? inEvent = p['inEvent'] as Map<String, dynamic>?;
                final Map<String, dynamic>? outEvent = p['outEvent'] as Map<String, dynamic>?;
                final bool? inInside = (inEvent?['insideOffice']) as bool?;
                final double? inDist = (inEvent?['distanceMeters'] as num?)?.toDouble();
                final bool? outInside = (outEvent?['insideOffice']) as bool?;
                final double? outDist = (outEvent?['distanceMeters'] as num?)?.toDouble();
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('Check In: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(i != null ? _fmtTime(i) : '-'),
                              const SizedBox(width: 8),
                              _locBadgeNullable(inInside, inDist),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Text('Check Out: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text(o != null ? _fmtTime(o) : '-'),
                              const SizedBox(width: 8),
                              _locBadgeNullable(outInside, outDist),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade200)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(dur, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
              Row(
                children: [
                  const Text('Total worked:'),
                  const SizedBox(width: 6),
                  Text(_fmtDuration(total), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              )
            ]
          ],
        );
      },
    );
  }


  // Leave request UI moved to LeavesPanel

  // Balances & Holidays moved to LeavesPanel

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(children: [Text('$k: '), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} hrs';
  }

  Widget _locBadge({required bool inside, double? distance}) {
    return Container(
      decoration: BoxDecoration(
        color: inside ? Colors.teal.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inside ? Colors.teal.shade200 : Colors.orange.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        Icon(inside ? Icons.place : Icons.place_outlined, size: 14, color: inside ? Colors.teal : Colors.orange),
        const SizedBox(width: 4),
        Text(inside ? 'Inside office' : 'Outside', style: TextStyle(color: inside ? Colors.teal.shade800 : Colors.orange.shade800)),
        if (distance != null) ...[
          const SizedBox(width: 6),
          Text('${distance.toStringAsFixed(1)} m', style: TextStyle(color: inside ? Colors.teal.shade800 : Colors.orange.shade800)),
        ],
      ]),
    );
  }

  Widget _locBadgeNullable(bool? inside, double? distance) {
    if (inside == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: const [
          Icon(Icons.help_outline, size: 14, color: Colors.grey),
          SizedBox(width: 4),
          Text('No location', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return _locBadge(inside: inside, distance: distance);
  }

  // removed: _dateKeyFor (not needed after demo/day selector removal)

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _fmtDateOnly(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }


  Widget _recentDaysPanel() {
    // Fetch last 30 day docs for the current user and render grouped lists
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('attendance')
          .where('uid', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snap) {
        final dayDocs = snap.data?.docs ?? [];
        // Sort locally to avoid composite index on (uid, dateKey)
        dayDocs.sort((a, b) => (b.data()['dateKey'] ?? '').toString().compareTo((a.data()['dateKey'] ?? '').toString()));
        final limited = dayDocs.take(30).toList();
        if (limited.isEmpty) return const Text('No recent days.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _monthlyTotalBar(),
            const SizedBox(height: 8),
            const Text('Recent — Last 30 days', style: TextStyle(fontWeight: FontWeight.w700)),
            const Divider(),
            ...limited.map((d) {
              final dk = (d.data()['dateKey'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _dayGroup(d.id, dk),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _monthlyTotalBar() {
    return FutureBuilder<Duration>(
      future: _computeMonthTotal(),
      builder: (context, snap) {
        final total = snap.data ?? Duration.zero;
        return Row(
          children: [
            Text(_monthLabel(_selectedDay), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade200)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('Month total: ${_fmtDuration(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<Duration> _computeMonthTotal() async {
    final y = _selectedDay.year;
    final m = _selectedDay.month;
    Duration total = Duration.zero;
    try {
      final q = await _firestore.collection('attendance').where('uid', isEqualTo: _uid).get();
      // Filter docs by month/year
      final monthDocs = q.docs.where((d) {
        final dk = (d.data()['dateKey'] ?? '').toString();
        if (dk.length < 7) return false;
        final parts = dk.split('-');
        if (parts.length < 3) return false;
        final yy = int.tryParse(parts[0]);
        final mm = int.tryParse(parts[1]);
        return yy == y && mm == m;
      }).toList();
      // Fetch punches for each doc in parallel
      final futures = monthDocs.map((d) async {
        final punches = await d.reference.collection('punches').orderBy('at').get();
        DateTime? inAt;
        for (final p in punches.docs) {
          final data = p.data();
          final type = (data['type'] ?? '').toString();
          final at = (data['at'] as Timestamp?)?.toDate();
          if (type == 'in') {
            inAt = at;
          } else if (type == 'out') {
            if (inAt != null && at != null) {
              total += at.difference(inAt);
            }
            inAt = null;
          }
        }
      }).toList();
      await Future.wait(futures);
    } catch (_) {}
    return total;
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _dayGroup(String docId, String dateKey) {
    final label = dateKey.replaceAll('-', '/');
    final docRef = _firestore.collection('attendance').doc(docId);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: docRef.collection('punches').orderBy('at').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final events = docs.map((e) => e.data()).toList();
        // Build pairs as done above
        final pairs = <Map<String, dynamic>>[];
        Map<String, dynamic>? pendingInEvent;
        for (final e in events) {
          final type = (e['type'] ?? '').toString();
          final at = (e['at'] as Timestamp?)?.toDate();
          if (type == 'in') {
            pendingInEvent = {...e, 'at': at};
          } else if (type == 'out') {
            final outEvent = {...e, 'at': at};
            pairs.add({
              'in': (pendingInEvent?['at'] as DateTime?),
              'out': at,
              'inEvent': pendingInEvent,
              'outEvent': outEvent,
            });
            pendingInEvent = null;
          }
        }
        if (pendingInEvent != null) {
          pairs.add({'in': (pendingInEvent['at'] as DateTime?), 'out': null, 'inEvent': pendingInEvent, 'outEvent': null});
        }
        if (pairs.isEmpty) return const SizedBox.shrink();

        Duration total = Duration.zero;
        for (final p in pairs) {
          final DateTime? i = p['in'] as DateTime?;
          final DateTime? o = p['out'] as DateTime?;
          if (i != null && o != null) total += o.difference(i);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade200)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('Total: ${_fmtDuration(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...pairs.map((p) {
              final DateTime? i = p['in'] as DateTime?;
              final DateTime? o = p['out'] as DateTime?;
              final dur = (i != null && o != null) ? _fmtDuration(o.difference(i)) : 'Open';
              final Map<String, dynamic>? inEvent = p['inEvent'] as Map<String, dynamic>?;
              final Map<String, dynamic>? outEvent = p['outEvent'] as Map<String, dynamic>?;
              final bool? inInside = (inEvent?['insideOffice']) as bool?;
              final double? inDist = (inEvent?['distanceMeters'] as num?)?.toDouble();
              final bool? outInside = (outEvent?['insideOffice']) as bool?;
              final double? outDist = (outEvent?['distanceMeters'] as num?)?.toDouble();
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('Check In: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(i != null ? _fmtTime(i) : '-'),
                            const SizedBox(width: 8),
                            _locBadgeNullable(inInside, inDist),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Text('Check Out: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(o != null ? _fmtTime(o) : '-'),
                            const SizedBox(width: 8),
                            _locBadgeNullable(outInside, outDist),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade200)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(dur, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // _fmtDate moved with Holidays view to LeavesPanel
}
