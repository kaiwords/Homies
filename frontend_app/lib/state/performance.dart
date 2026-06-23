// Pure tenant track-record computation, shared by the Tenant Performance
// screen and the in-post performance-reference share. No UI imports here so it
// can be reused anywhere (colours/tones are decided by the caller).

import '../util/format.dart';
import 'app_state.dart';
import 'models.dart';

const complaintThreshold = 100;

class TenantStats {
  final User user;
  final bool hasActivity;
  // Cleaning
  final int taskCount;
  final int doneCount;
  final int overdueCount;
  final int excusedCount;
  final double? choreRate;
  // Bills
  final int billCount;
  final int paidCount;
  final double owed;
  final int lateUnpaid;
  final double? billRate;
  // Subscriptions
  final int subCount;
  final int subPaidCount;
  final double? subRate;
  // Groceries
  final int groceriesCount;
  final int groceriesPaidCount;
  final double? groceriesRate;
  // Necessities
  final int necessitiesCount;
  final int necessitiesPaidCount;
  final double? necessitiesRate;
  // Engagement
  final int complaintSeverity;
  final int partiesHosted;
  final int issuesRaised;
  final int groupMessageCount;
  // Score
  final int standing;

  TenantStats({
    required this.user,
    required this.hasActivity,
    required this.taskCount,
    required this.doneCount,
    required this.overdueCount,
    required this.excusedCount,
    required this.choreRate,
    required this.billCount,
    required this.paidCount,
    required this.owed,
    required this.lateUnpaid,
    required this.billRate,
    required this.subCount,
    required this.subPaidCount,
    required this.subRate,
    required this.groceriesCount,
    required this.groceriesPaidCount,
    required this.groceriesRate,
    required this.necessitiesCount,
    required this.necessitiesPaidCount,
    required this.necessitiesRate,
    required this.complaintSeverity,
    required this.partiesHosted,
    required this.issuesRaised,
    required this.groupMessageCount,
    required this.standing,
  });
}

bool _isPast(String? iso) {
  final d = parseIso(iso);
  if (d == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(d.year, d.month, d.day).isBefore(today);
}

TenantStats computeTenantStats(User u, HomiesState s) {
  // Cleaning
  final tasks = s.cleaningTasks.where((t) => t.assignee == u.id).toList();
  final done = tasks.where((t) => t.done).length;
  final overdue = tasks.where((t) => !t.done && (t.excuse == null || t.excuse!.isEmpty) && _isPast(t.dueDate)).length;
  final excused = tasks.where((t) => (t.excuse != null && t.excuse!.isNotEmpty) && !t.done).length;
  final choreRate = tasks.isEmpty ? null : done / tasks.length;

  // Bills
  final shares = s.bills.where((b) => b.shares.containsKey(u.id)).toList();
  final paid = shares.where((b) => b.paidBy[u.id] == true).length;
  final owed = shares.where((b) => b.paidBy[u.id] != true).fold<double>(0, (a, b) => a + (b.shares[u.id] ?? 0));
  final lateUnpaid = shares.where((b) => b.paidBy[u.id] != true && _isPast(b.dueDate)).length;
  final billRate = shares.isEmpty ? null : paid / shares.length;

  // Subscriptions — track where user is participant but not the payer
  final subOwed = s.subscriptions.where((sub) => sub.participants.contains(u.id) && sub.payer != u.id).toList();
  final subPaidCount = subOwed.where((sub) => sub.paidBy[u.id] == true).length;
  final subRate = subOwed.isEmpty ? null : subPaidCount / subOwed.length;

  // Groceries — shared runs where user owes a share
  final grocShared = s.groceries.where((g) => g.mode == 'shared' && g.shares.containsKey(u.id) && g.payer != u.id).toList();
  final grocPaid = grocShared.where((g) => g.paidBy[u.id] == true).length;
  final groceriesRate = grocShared.isEmpty ? null : grocPaid / grocShared.length;

  // Necessities — shared items where user owes a share
  final necShared = s.necessities.where((n) => n.mode == 'shared' && n.shares.containsKey(u.id) && n.payer != u.id).toList();
  final necPaid = necShared.where((n) => n.paidBy[u.id] == true).length;
  final necessitiesRate = necShared.isEmpty ? null : necPaid / necShared.length;

  // Complaints & parties
  final against = s.complaints.where((c) => c.against == u.id).toList();
  final complaintSeverity = against.fold<int>(0, (a, c) => a + c.severity);
  final issuesRaised = s.complaints.where((c) => c.from == u.id).length;
  final partiesHosted = s.parties.where((p) => p.host == u.id).length;

  // Group chat participation
  final groupMessageCount = s.messages.group.where((m) => m.from == u.id).length;

  final hasActivity = tasks.isNotEmpty || shares.isNotEmpty || against.isNotEmpty ||
      partiesHosted > 0 || subOwed.isNotEmpty || grocShared.isNotEmpty || necShared.isNotEmpty;

  // Standing score
  final choreScore = choreRate ?? 1.0;
  final billScore = billRate ?? 1.0;
  final complaintScore = (1 - (complaintSeverity / complaintThreshold).clamp(0.0, 1.0)).clamp(0.0, 1.0);
  var standing = (45 * choreScore + 30 * billScore + 25 * complaintScore).round();
  standing -= overdue * 4 + lateUnpaid * 4;
  standing = standing.clamp(0, 100);

  return TenantStats(
    user: u,
    hasActivity: hasActivity,
    taskCount: tasks.length,
    doneCount: done,
    overdueCount: overdue,
    excusedCount: excused,
    choreRate: choreRate,
    billCount: shares.length,
    paidCount: paid,
    owed: owed,
    lateUnpaid: lateUnpaid,
    billRate: billRate,
    subCount: subOwed.length,
    subPaidCount: subPaidCount,
    subRate: subRate,
    groceriesCount: grocShared.length,
    groceriesPaidCount: grocPaid,
    groceriesRate: groceriesRate,
    necessitiesCount: necShared.length,
    necessitiesPaidCount: necPaid,
    necessitiesRate: necessitiesRate,
    complaintSeverity: complaintSeverity,
    partiesHosted: partiesHosted,
    issuesRaised: issuesRaised,
    groupMessageCount: groupMessageCount,
    standing: standing,
  );
}

/// Plain-text standing band — callers map this to their own colour/chip tone.
String standingBand(int score) {
  if (score >= 80) return 'Good';
  if (score >= 60) return 'Fair';
  return 'Needs attention';
}

/// Build a shareable reference snapshot for a tenant from the live state.
PerfSnapshot snapshotFor(User u, HomiesState s, {String? note}) {
  final st = computeTenantStats(u, s);
  return PerfSnapshot(
    standing: st.standing,
    band: standingBand(st.standing),
    doneCount: st.doneCount,
    taskCount: st.taskCount,
    choreRate: st.choreRate,
    paidCount: st.paidCount,
    billCount: st.billCount,
    billRate: st.billRate,
    complaintSeverity: st.complaintSeverity,
    partiesHosted: st.partiesHosted,
    house: s.property.address,
    note: note,
    lifestyle: u.lifestyle,
  );
}
