import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/state/models.dart';

void main() {
  group('User serialization', () {
    test('toJson/fromJson round-trip survives jsonEncode', () {
      final u = User(
        id: 'u1',
        name: 'Alex Chen',
        initials: 'AC',
        role: 'leaseholder',
        email: 'alex@example.com',
        phone: '0400 000 000',
        moveInDate: '2026-01-01',
        bondPaid: true,
        bondAmount: 1200.50,
        docVerified: true,
        houseId: 'house-1',
      );
      final decoded = User.fromJson(jsonDecode(jsonEncode(u.toJson())) as Map<String, dynamic>);
      expect(decoded.id, u.id);
      expect(decoded.name, u.name);
      expect(decoded.role, u.role);
      expect(decoded.email, u.email);
      expect(decoded.moveInDate, u.moveInDate);
      expect(decoded.bondPaid, isTrue);
      expect(decoded.bondAmount, 1200.50);
      expect(decoded.docVerified, isTrue);
      expect(decoded.houseId, 'house-1');
    });

    test('fromJson tolerates missing optional fields', () {
      final u = User.fromJson({
        'id': 'u2',
        'name': 'Sam',
        'initials': 'S',
        'role': 'tenant',
      });
      expect(u.email, '');
      expect(u.bondPaid, isFalse);
      expect(u.member, isTrue);
      expect(u.shareEmergency, isFalse);
      expect(u.lifestyle, isNull);
    });

    test('fromFirestoreDoc defaults every missing field instead of throwing', () {
      final u = User.fromFirestoreDoc('uid-9', {});
      expect(u.id, 'uid-9');
      expect(u.name, '');
      expect(u.initials, '??');
      expect(u.role, 'tenant');
      expect(u.pending, isTrue);
      expect(u.bondAmount, 0);
    });

    test('fromFirestoreDoc derives initials from the name when absent', () {
      final u = User.fromFirestoreDoc('uid-10', {'name': 'jane maree doe'});
      expect(u.initials, 'JM');
    });
  });

  group('Bill serialization', () {
    test('round-trip preserves shares, paidBy and integer amounts as doubles', () {
      final b = Bill(
        id: 'b1',
        title: 'Electricity',
        category: 'utilities',
        amount: 240,
        dueDate: '2026-08-01',
        issuedBy: 'u1',
        split: 'equal',
        shares: {'u1': 120.0, 'u2': 120.0},
        paidBy: {'u1': true},
      );
      final decoded = Bill.fromJson(jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);
      expect(decoded.amount, 240.0);
      expect(decoded.shares, {'u1': 120.0, 'u2': 120.0});
      expect(decoded.paidBy, {'u1': true});
      expect(decoded.status, 'pending');
      expect(decoded.proof, isNull);
    });

    test('fromJson tolerates a minimal document', () {
      final b = Bill.fromJson({'id': 'b2', 'title': 'Water'});
      expect(b.category, 'other');
      expect(b.amount, 0);
      expect(b.split, 'equal');
      expect(b.shares, isEmpty);
      expect(b.paidBy, isEmpty);
    });
  });

  group('CleaningTask serialization', () {
    test('round-trip preserves excuse and completion state', () {
      final t = CleaningTask(
        id: 'c1',
        task: 'Mop floors',
        assignee: 'u1',
        dueDate: '2026-07-20',
        done: true,
        completedAt: '2026-07-19T10:00:00',
        excuse: null,
      );
      final decoded = CleaningTask.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(decoded.task, 'Mop floors');
      expect(decoded.done, isTrue);
      expect(decoded.completedAt, '2026-07-19T10:00:00');
      expect(decoded.excuse, isNull);
    });
  });
}
