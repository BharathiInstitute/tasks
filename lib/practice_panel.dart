// ignore_for_file: use_build_context_synchronously
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PracticePanel extends StatelessWidget {
  const PracticePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('templateGoals')
              .where('assigneeEmail', isEqualTo: email.isEmpty ? '__none__' : email)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red));
            }
            final rawDocs = snap.data?.docs ?? [];
            final List<QueryDocumentSnapshot> docs = rawDocs.cast<QueryDocumentSnapshot>();
            docs.sort((a, b) {
              final da = (a.data() as Map<String, dynamic>)['templateNumber'];
              final db = (b.data() as Map<String, dynamic>)['templateNumber'];
              final ia = da is int ? da : (da is num ? da.toInt() : 0);
              final ib = db is int ? db : (db is num ? db.toInt() : 0);
              return ia.compareTo(ib);
            });
            if (docs.isEmpty) {
              return const Center(
                  child: Text('No goals assigned',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)));
            }
            // Re-introduced FAB for adding work; stays at bottom-right while scrolling.
            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PracticePanel v2', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: [for (final d in docs) _bigGoalCard(d)],
                        ),
                        const SizedBox(height: 40),
                        Text('My Work', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _myWorkList(email),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: FloatingActionButton.extended(
                    heroTag: 'workFab',
                    onPressed: () => _openWorkDialog(context, docs),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Add Work'),
                  ),
                ),
              ],
            );
          },
        ));
    
  }
  // _openWorkDialog method removed with form functionality.
  Future<void> _openWorkDialog(BuildContext context, List<QueryDocumentSnapshot> goalDocs) async {
    if (goalDocs.isEmpty) return;
    final formKey = GlobalKey<FormState>();
    QueryDocumentSnapshot? selected = goalDocs.first;
  final noteCtrl = TextEditingController();
  final linkCtrl = TextEditingController();
    bool saving = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        return AlertDialog(
          title: const Text('Add Work Entry'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<QueryDocumentSnapshot>(
                    value: selected,
                    decoration: const InputDecoration(labelText: 'Goal'),
                    items: goalDocs.map((g){
                      final d = g.data() as Map<String,dynamic>;
                      final name = (d['name'] ?? '').toString();
                      return DropdownMenuItem(value: g, child: Text(name));
                    }).toList(),
                    onChanged: (v)=> setM(()=> selected = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(labelText: 'Link (optional)', border: OutlineInputBorder(), hintText: 'https://...'),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Work Notes', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (selected == null) {
                  return;
                }
                setM(()=> saving = true);
                try {
                  final ref = selected!;
                  final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? '';
                  final selData = (ref.data() as Map<String,dynamic>?) ?? {};
                  final goalNumber = selData['templateNumber'];
                  final goalName = selData['name'];
                  await FirebaseFirestore.instance.runTransaction((tx) async {
                    final snap = await tx.get(ref.reference);
                    final cur = snap.data() as Map<String,dynamic>?;
                    int? target;
                    int remaining = 0;
                    if (cur != null) {
                      final t = cur['templateNumber'];
                      if (t is int) {
                        target = t;
                      } else if (t is num) {
                        target = t.toInt();
                      }
                      final r = cur['remaining'];
                      if (r is int) {
                        remaining = r;
                      } else if (r is num) {
                        remaining = r.toInt();
                      } else {
                        remaining = -1; // mark missing
                      }
                    }
                    if (remaining < 0) {
                      // remaining missing; initialize from target (if present)
                      remaining = (target ?? 0);
                    }
                    if (remaining > 0) {
                      remaining -= 1; // decrement once per work log
                    }
                    tx.update(ref.reference, {
                      'remaining': remaining,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    final workCol = ref.reference.collection('workLogs').doc();
                    tx.set(workCol, {
                      'id': workCol.id,
                      'note': noteCtrl.text.trim(),
                      'ts': FieldValue.serverTimestamp(),
                      'email': userEmail,
                      'goalId': ref.id,
                      'templateNumber': goalNumber,
                      'goalName': goalName,
                      'link': linkCtrl.text.trim(),
                    });
                  });
                  // Also append to userWorkLogs (separate collection) outside transaction
                  if (userEmail.isNotEmpty) {
                    final uw = FirebaseFirestore.instance.collection('userWorkLogs').doc();
                    await uw.set({
                      'id': uw.id,
                      'email': userEmail,
                      'goalId': ref.id,
                      'note': noteCtrl.text.trim(),
                      'ts': FieldValue.serverTimestamp(),
                      'templateNumber': goalNumber,
                      'goalName': goalName,
                      'link': linkCtrl.text.trim(),
                    });
                  }
                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                } finally {
                  setM(()=> saving = false);
                }
              },
              child: saving ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Add'),
            ),
          ],
        );
      })
    );
  }

  Widget _bigGoalCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
  final number = data['templateNumber']; // still used for color selection
    final name = (data['name'] ?? '').toString();
    int rem = 0; final r = data['remaining']; if (r is int) {
      rem = r;
    } else if (r is num) {
      rem = r.toInt();
    }
    // number was hidden earlier; now re‑show per request
    final palette = [Colors.indigo, Colors.teal, Colors.orange, Colors.pink, Colors.deepPurple, Colors.blue];
    final color = palette[(number is int ? number : 0) % palette.length];
  return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
      decoration: BoxDecoration(
    color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
    border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name on top
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color.darken(.25),
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          // Show only the remaining number (or '-' if none) under the name.
          Text(
            rem > 0 ? rem.toString() : (rem == 0 ? '0' : '-'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color.darken(.35),
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
  // Removed per-goal work logs preview; consolidated work appears in main list below.


  Widget _myWorkList(String email) {
    if (email.isEmpty) return const SizedBox();
    return Container(
  width: double.infinity,
  padding: const EdgeInsets.fromLTRB(18,16,18,12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('userWorkLogs')
            .where('email', isEqualTo: email)
            .orderBy('ts', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          // If index missing error -> offer fallback without ordering (client sorts) so UI still works while index builds.
          if (snap.hasError && snap.error.toString().contains('failed-precondition')) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom:12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Text('Building index... temporary unordered view shown. (Deploy email ASC + ts DESC index if not already)')
                ),
                _fallbackWorkList(email),
              ],
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth:2)));
          }
          if (snap.hasError) {
            return Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red));
          }
          final List<QueryDocumentSnapshot> docs = (snap.data?.docs ?? []).cast<QueryDocumentSnapshot>();
          if (docs.isEmpty) {
            return const Text('No work entries yet', style: TextStyle(fontSize:12, fontStyle: FontStyle.italic));
          }
          return _renderWorkDocs(docs);
        },
      ),
    );
  }

  Widget _fallbackWorkList(String email) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('userWorkLogs')
          .where('email', isEqualTo: email)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(height:40, child: Center(child: CircularProgressIndicator(strokeWidth:2)));
        }
  final List<QueryDocumentSnapshot> docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a,b){
          final ad = a.data() as Map<String,dynamic>; final bd = b.data() as Map<String,dynamic>;
          final at = ad['ts']; final bt = bd['ts'];
            DateTime? aT; if (at is Timestamp) aT = at.toDate();
            DateTime? bT; if (bt is Timestamp) bT = bt.toDate();
          return (bT??DateTime.fromMillisecondsSinceEpoch(0)).compareTo(aT??DateTime.fromMillisecondsSinceEpoch(0));
        });
  return _renderWorkDocs(docs);
      },
    );
  }

  Widget _renderWorkDocs(List<QueryDocumentSnapshot> docs) {
    return Column(
      children: [
        // Header card styled similar to tasks header
  Card(
          margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          elevation: 1,
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
    Expanded(flex: 2, child: Text('Goal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
    Expanded(flex: 2, child: Text('Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
    Expanded(flex: 3, child: Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
    SizedBox(width: 130, child: Text('Created', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ),
  ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final raw = docs[i];
            final d = raw.data() as Map<String,dynamic>;
            final note = (d['note'] ?? '').toString();
            final numVal = d['templateNumber'];
            final goalName = (d['goalName'] ?? '').toString();
            final link = (d['link'] ?? '').toString();
            final ts = d['ts'];
            DateTime? dt; if (ts is Timestamp) dt = ts.toDate();
            final createdStr = dt == null ? '' : _fmtDate(dt);
            final color = _paletteColorFor(numVal);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              elevation: .7,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _editWorkDialog(context, raw.id),
                onLongPress: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete Work Log'),
                      content: const Text('Delete this work log entry? This will increase the goal remaining count by 1.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      final snap = await FirebaseFirestore.instance.collection('userWorkLogs').doc(raw.id).get();
                      final data = snap.data();
                      final goalId = (data?['goalId'] ?? '').toString();
                      if (goalId.isNotEmpty) {
                        final goalRef = FirebaseFirestore.instance.collection('templateGoals').doc(goalId);
                        await FirebaseFirestore.instance.runTransaction((tx) async {
                          final gSnap = await tx.get(goalRef);
                          final gData = gSnap.data();
                          int remaining = 0;
                          int? tmpl;
                          if (gData != null) {
                            final r = gData['remaining'];
                            if (r is int) {
                              remaining = r;
                            } else if (r is num) {
                              remaining = r.toInt();
                            } else {
                              remaining = -1;
                            }
                            final t = gData['templateNumber'];
                            if (t is int) {
                              tmpl = t;
                            } else if (t is num) {
                              tmpl = t.toInt();
                            }
                          }
                          if (remaining < 0) {
                            remaining = tmpl ?? 0;
                          }
                          remaining += 1;
                          tx.update(goalRef, {'remaining': remaining, 'updatedAt': FieldValue.serverTimestamp()});
                        });
                      }
                      await FirebaseFirestore.instance.collection('userWorkLogs').doc(raw.id).delete();
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work log deleted')));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          goalName.isEmpty ? '(Goal)' : goalName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color.darken(.5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: link.isEmpty
                            ? const Text('-', style: TextStyle(fontSize: 11, color: Colors.black54))
                            : _linkWidget(link),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          note,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(width:130, child: Text(createdStr, style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _paletteColorFor(dynamic number) {
    final palette = [Colors.indigo, Colors.teal, Colors.orange, Colors.pink, Colors.deepPurple, Colors.blue];
    int idx = 0; if (number is int) {
      idx = number;
    } else if (number is num) {
      idx = number.toInt();
    }
    return palette[idx % palette.length];
  }

  String _fmtDate(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<void> _editWorkDialog(BuildContext context, String docId) async {
    // Load existing work log
    final workRef = FirebaseFirestore.instance.collection('userWorkLogs').doc(docId);
    final workSnap = await workRef.get();
    if (!workSnap.exists) return;
  final workData = workSnap.data() ?? {};
  final oldGoalId = (workData['goalId'] ?? '').toString();
  String oldGoalName = (workData['goalName'] ?? '').toString();
    final oldNote = (workData['note'] ?? '').toString();
    final oldLink = (workData['link'] ?? '').toString();

    // Fetch goals for dropdown
  // email no longer needed for read-only goal display
    // Fetch goal name if missing
    if (oldGoalName.isEmpty && oldGoalId.isNotEmpty) {
      try {
        final g = await FirebaseFirestore.instance.collection('templateGoals').doc(oldGoalId).get();
        oldGoalName = (g.data()?['name'] ?? '').toString();
      } catch (_) {}
    }

    final noteCtrl = TextEditingController(text: oldNote);
    final linkCtrl = TextEditingController(text: oldLink);
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => AlertDialog(
          title: const Text('Edit Work Entry'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    readOnly: true,
                    initialValue: oldGoalName.isEmpty ? '(Goal)' : oldGoalName,
                    decoration: const InputDecoration(labelText: 'Goal', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'https://...',
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Work Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter notes' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      // Goal is fixed (read-only) in edit; only updating note/link.
                      setM(() => saving = true);
                      try {
                        await workRef.update({
                          'note': noteCtrl.text.trim(),
                          'link': linkCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Update failed: $e')),
                        );
                      } finally {
                        setM(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkWidget(String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
        if (uri == null) return;
        try {
          // ignore: deprecated_member_use
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          url,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// Simple color darken extension
extension _ColorShade on Color {
  Color darken([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final darker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darker.toColor();
  }
}
