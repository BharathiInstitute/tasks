import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Simple employee home dashboard showing summary counts of the
/// logged-in employee's tasks by status.
class EmployeeHomePanel extends StatelessWidget {
	const EmployeeHomePanel({super.key});

	bool _isTaskMine(Map<String, dynamic> t, User? user, String displayName, String email) {
		final uid = user?.uid;
		final assigneeUid = (t['assigneeUid'] ?? '').toString();
		final assignTo = (t['assignTo'] ?? '').toString();
		final assigneeEmail = (t['assigneeEmail'] ?? '').toString();
		final createdBy = (t['createdBy'] ?? '').toString();
		return (uid != null && (assigneeUid == uid || createdBy == uid)) ||
				(assignTo.isNotEmpty && assignTo.toLowerCase() == displayName.toLowerCase()) ||
				(email.isNotEmpty && assigneeEmail.toLowerCase() == email.toLowerCase());
	}

	@override
	Widget build(BuildContext context) {
		final authUser = FirebaseAuth.instance.currentUser;
		final displayEmail = (authUser?.email ?? '').trim();
		final displayName = (authUser?.displayName ?? '').trim().isNotEmpty
				? (authUser?.displayName ?? '').trim()
				: (displayEmail.isNotEmpty ? displayEmail.split('@').first : 'User');

		return StreamBuilder<QuerySnapshot>(
			stream: FirebaseFirestore.instance.collection('tasks').snapshots(),
			builder: (context, snap) {
				final docs = snap.data?.docs ?? [];
				int working = 0, pending = 0, completed = 0, total = 0;
				for (final d in docs) {
					final data = d.data() as Map<String, dynamic>;
					if (_isTaskMine(data, authUser, displayName, displayEmail)) {
						final status = (data['status'] ?? '').toString().toLowerCase();
						total++;
						if (status.contains('complete')) {
							completed++;
						} else if (status.contains('work')) {
							working++;
						} else if (status.contains('pending')) {
							pending++;
						}
					}
				}

				Widget summaryCard({required String label, int? count, String? value, Color? color, IconData icon = Icons.task_alt}) {
					return Card(
						elevation: 1.2,
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
						child: Container(
							padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
							width: 220,
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
											Icon(icon, color: color ?? Colors.blue, size: 22),
											const SizedBox(width: 8),
											Expanded(
												child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? Colors.blueGrey[700])),
											),
										],
									),
									const SizedBox(height: 10),
									Text(value ?? (count?.toString() ?? '-'), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: color ?? Colors.blue[700])),
								],
							),
						),
					);
				}

				return Transform.translate(
					offset: const Offset(0,-40), // pull further upward to remove top gap
					child: SingleChildScrollView(
					padding: const EdgeInsets.fromLTRB(16,0,16,16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text('Welcome, $displayName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
							const SizedBox(height: 4),
							Text('Here\'s a quick summary of your tasks', style: TextStyle(color: Colors.grey[700])),
							const SizedBox(height: 14),
							Wrap(
								spacing: 16,
								runSpacing: 16,
								children: [
									summaryCard(label: 'Total Tasks', count: total, color: Colors.indigo, icon: Icons.all_inbox_outlined),
									summaryCard(label: 'Working', count: working, color: Colors.blue, icon: Icons.work_history_outlined),
									summaryCard(label: 'Pending', count: pending, color: Colors.orange, icon: Icons.pending_actions_outlined),
									summaryCard(label: 'Completed', count: completed, color: Colors.green, icon: Icons.check_circle_outline),
								],
							),
							const SizedBox(height: 20),
										if (total == 0) ...[
											const Text('You have no tasks yet. Use the Add Task button to create one.', style: TextStyle(color: Colors.black54)),
												] else ...[
												Text('Keep going! ${completed == total && total > 0 ? "All done" : "You have ${total - completed} open tasks"}.', style: const TextStyle(fontWeight: FontWeight.w500)),
												],

							// ===== Practice Template Summary (below tasks) =====
							const SizedBox(height: 24),
							Text('Practice Goals Summary', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
							const SizedBox(height: 10),
							StreamBuilder<QuerySnapshot>(
								stream: FirebaseFirestore.instance.collection('templateGoals').where('assigneeEmail', isEqualTo: displayEmail.toLowerCase()).snapshots(),
								builder: (context, gSnap) {
									// Even while loading, show zeroed cards
									final gDocs = gSnap.data?.docs ?? [];
									int totalTemplates = gDocs.length;
									int totalTarget = 0; // sum of templateNumber
									int totalRemaining = 0; // sum of remaining
										for (final d in gDocs) {
											final data = d.data() as Map<String,dynamic>;
											final t = data['templateNumber'];
											final r = data['remaining'];
											if (t is int) {
												totalTarget += t;
											} else if (t is num) {
												totalTarget += t.toInt();
											}
											if (r is int) {
												totalRemaining += r;
											} else if (r is num) {
												totalRemaining += r.toInt();
											}
										}
									int totalDone = totalTarget - totalRemaining; if (totalDone < 0) totalDone = 0;
									return Wrap(
										spacing: 16,
										runSpacing: 16,
										children: [
											summaryCard(label: 'Templates Goals', count: totalTemplates, color: Colors.purple, icon: Icons.view_module_outlined),
											summaryCard(label: 'Total Target', count: totalTarget, color: Colors.deepPurple, icon: Icons.flag_outlined),
											summaryCard(label: 'Remaining', count: totalRemaining, color: Colors.redAccent, icon: Icons.timelapse_outlined),
											summaryCard(label: 'Completed Practice', count: totalDone, color: Colors.green, icon: Icons.checklist_outlined),
										],
									);
								},
							),
							// ===== Attendance Summary (worked hours) =====
							const SizedBox(height: 24),
							Text('Attendance Summary', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
							const SizedBox(height: 10),
							StreamBuilder<QuerySnapshot>(
								stream: FirebaseFirestore.instance.collection('attendance').where('uid', isEqualTo: authUser?.uid ?? '').snapshots(),
								builder: (context, aSnap) {
									// Show zero cards during load too
										final aDocs = aSnap.data?.docs ?? [];
										final now = DateTime.now();
										final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1)); // Monday start
										final weekEnd = weekStart.add(const Duration(days: 7));
										DateTime? parseKey(String k){ if(k.length<10) return null; final p=k.split('-'); if(p.length<3) return null; final y=int.tryParse(p[0]); final m=int.tryParse(p[1]); final d=int.tryParse(p[2]); if(y==null||m==null||d==null) return null; return DateTime(y,m,d); }

										Future<Map<String,Duration>> loadDurations() async {
											Duration monthDur = Duration.zero;
											Duration weekDur = Duration.zero;
											Duration dayDur = Duration.zero;
											// Filter docs to only those that could affect current month/week/today before fetching punches
											final eligible = <QueryDocumentSnapshot>[];
											final parsedDates = <String,DateTime>{};
											for(final doc in aDocs){
												final dk = ((doc.data() as Map<String,dynamic>)['dateKey']??'').toString();
												final date = parseKey(dk); if(date==null) continue; parsedDates[doc.id] = date;
												final inMonth = date.year==now.year && date.month==now.month;
												final inWeek = !date.isBefore(weekStart) && date.isBefore(weekEnd);
												final isToday = date.year==now.year && date.month==now.month && date.day==now.day;
												if(inMonth || inWeek || isToday){ eligible.add(doc); }
											}
											// Fetch punches concurrently for eligible docs
											final futures = eligible.map((doc)=> doc.reference.collection('punches').orderBy('at').get()).toList();
											List<QuerySnapshot> punchesSnaps = [];
											try {
												punchesSnaps = await Future.wait(futures);
											} catch (e) {
												// On error just return zeros so UI still renders
												return {'month': monthDur, 'week': weekDur, 'day': dayDur};
											}
											for(int i=0;i<eligible.length;i++){
												final doc = eligible[i];
												final date = parsedDates[doc.id]!;
												final punchesSnap = punchesSnaps[i];
												DateTime? openIn; Duration dayTotal = Duration.zero; Duration todayAccum = Duration.zero; final isToday = date.year==now.year && date.month==now.month && date.day==now.day;
												for(final p in punchesSnap.docs){
													final pdata = p.data() as Map<String,dynamic>; final type = (pdata['type']??'').toString(); final at = (pdata['at'] as Timestamp?)?.toDate(); if(at==null) continue;
													if(type=='in'){ openIn = at; }
													else if(type=='out' && openIn!=null){
														final diff = at.difference(openIn); dayTotal += diff; if(isToday) todayAccum += diff; openIn = null;
													}
												}
												if(openIn!=null){ final diff = now.difference(openIn); dayTotal += diff; if(isToday) todayAccum += diff; }
												if(date.year==now.year && date.month==now.month) monthDur += dayTotal;
												if(!date.isBefore(weekStart) && date.isBefore(weekEnd)) weekDur += dayTotal;
												if(isToday) dayDur = todayAccum;
											}
											return {'month': monthDur, 'week': weekDur, 'day': dayDur};
										}

										return FutureBuilder<Map<String,Duration>>(
											future: loadDurations(),
											builder: (c, snapDur){
												final data = snapDur.data;
												final monthDur = data?['month'] ?? Duration.zero;
												final weekDur = data?['week'] ?? Duration.zero;
												final dayDur = data?['day'] ?? Duration.zero;
												String fmt(Duration d){ final h=d.inHours; final m=d.inMinutes%60; return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}'; }
												return Wrap(
													spacing: 16,
													runSpacing: 16,
													children: [
														summaryCard(label: 'Attendance Days', count: aDocs.length, color: Colors.brown, icon: Icons.event_available_outlined),
														summaryCard(label: 'Month Worked', value: fmt(monthDur), color: Colors.deepOrange, icon: Icons.calendar_month_outlined),
														summaryCard(label: 'Week Worked', value: fmt(weekDur), color: Colors.indigo, icon: Icons.date_range_outlined),
														summaryCard(label: 'Day Worked', value: fmt(dayDur), color: Colors.teal, icon: Icons.access_time),
													],
												);
											}
										);
								},
							),
						],
					),
					),
				);
			},
		);
	}
}
