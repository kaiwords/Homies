import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/state/app_state.dart';
import 'package:homies_mobile/state/models.dart';
import 'package:homies_mobile/state/performance.dart';
import 'package:homies_mobile/util/format.dart';

// A distinctive id so seed data (which uses its own user ids) never collides
// with the tenant under test.
const _uid = 'zz-test-tenant';

User _tenant() => User(
      id: _uid,
      name: 'Test Tenant',
      initials: 'TT',
      role: 'tenant',
      email: 'tt@example.com',
      phone: '',
    );

HomiesState _cleanState() {
  final s = HomiesState();
  s.cleaningTasks = [];
  s.bills = [];
  s.subscriptions = [];
  s.groceries = [];
  s.necessities = [];
  s.complaints = [];
  s.parties = [];
  return s;
}

void main() {
  test('tenant with no activity scores a perfect default standing', () {
    final s = _cleanState();
    final st = computeTenantStats(_tenant(), s);
    expect(st.hasActivity, isFalse);
    expect(st.choreRate, isNull);
    expect(st.billRate, isNull);
    expect(st.owed, 0);
    expect(st.standing, 100);
    expect(standingBand(st.standing), 'Good');
  });

  test('perfect tenant: all chores done, all bills paid', () {
    final s = _cleanState();
    s.cleaningTasks = [
      CleaningTask(id: 'c1', task: 'Kitchen', assignee: _uid, dueDate: daysAgoIso(2), done: true),
      CleaningTask(id: 'c2', task: 'Bathroom', assignee: _uid, dueDate: daysAheadIso(2), done: true),
    ];
    s.bills = [
      Bill(
        id: 'b1',
        title: 'Power',
        category: 'utilities',
        amount: 120,
        dueDate: daysAgoIso(1),
        issuedBy: 'lh',
        split: 'equal',
        shares: {_uid: 60.0},
        paidBy: {_uid: true},
      ),
    ];
    final st = computeTenantStats(_tenant(), s);
    expect(st.hasActivity, isTrue);
    expect(st.choreRate, 1.0);
    expect(st.billRate, 1.0);
    expect(st.owed, 0);
    expect(st.lateUnpaid, 0);
    expect(st.standing, 100);
  });

  test('overdue chores and late unpaid bills drag the standing down', () {
    final s = _cleanState();
    s.cleaningTasks = [
      CleaningTask(id: 'c1', task: 'Kitchen', assignee: _uid, dueDate: daysAgoIso(3), done: true),
      CleaningTask(id: 'c2', task: 'Bins', assignee: _uid, dueDate: daysAgoIso(3), done: true),
      CleaningTask(id: 'c3', task: 'Floors', assignee: _uid, dueDate: daysAgoIso(3)),
      CleaningTask(id: 'c4', task: 'Windows', assignee: _uid, dueDate: daysAgoIso(3)),
    ];
    s.bills = [
      Bill(
        id: 'b1',
        title: 'Water',
        category: 'utilities',
        amount: 80,
        dueDate: daysAgoIso(5),
        issuedBy: 'lh',
        split: 'equal',
        shares: {_uid: 80.0},
      ),
      Bill(
        id: 'b2',
        title: 'Gas',
        category: 'utilities',
        amount: 40,
        dueDate: daysAgoIso(5),
        issuedBy: 'lh',
        split: 'equal',
        shares: {_uid: 40.0},
        paidBy: {_uid: true},
      ),
    ];
    final st = computeTenantStats(_tenant(), s);
    expect(st.taskCount, 4);
    expect(st.doneCount, 2);
    expect(st.overdueCount, 2);
    expect(st.choreRate, 0.5);
    expect(st.billRate, 0.5);
    expect(st.owed, 80.0);
    expect(st.lateUnpaid, 1);
    // (45*0.5 + 30*0.5 + 25*1) = 62.5 -> 63, minus 2 overdue*4 + 1 late*4 = 51.
    expect(st.standing, 51);
    expect(standingBand(st.standing), 'Needs attention');
  });

  test('excused undone chores are counted as excused, not overdue', () {
    final s = _cleanState();
    s.cleaningTasks = [
      CleaningTask(id: 'c1', task: 'Kitchen', assignee: _uid, dueDate: daysAgoIso(3), excuse: 'Away for work'),
    ];
    final st = computeTenantStats(_tenant(), s);
    expect(st.excusedCount, 1);
    expect(st.overdueCount, 0);
  });

  test('standing never drops below 0 or above 100', () {
    final s = _cleanState();
    s.cleaningTasks = List.generate(
      20,
      (i) => CleaningTask(id: 'c$i', task: 'T$i', assignee: _uid, dueDate: daysAgoIso(10)),
    );
    final st = computeTenantStats(_tenant(), s);
    expect(st.standing, inInclusiveRange(0, 100));
    expect(st.standing, 0);
  });

  test('standingBand boundaries', () {
    expect(standingBand(100), 'Good');
    expect(standingBand(80), 'Good');
    expect(standingBand(79), 'Fair');
    expect(standingBand(60), 'Fair');
    expect(standingBand(59), 'Needs attention');
    expect(standingBand(0), 'Needs attention');
  });

  test('snapshotFor mirrors the computed stats', () {
    final s = _cleanState();
    final snap = snapshotFor(_tenant(), s, note: 'Great tenant');
    expect(snap.standing, 100);
    expect(snap.band, 'Good');
    expect(snap.note, 'Great tenant');
    expect(snap.house, s.property.address);
  });
}
