import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:homies_mobile/state/models.dart';
import 'package:homies_mobile/state/sync_reconcile.dart';

/// Canonicalise a doc the same way the sync builds its baseline
/// (jsonEncode of the model's toJson()).
String _canon(Map<String, dynamic> json) => jsonEncode(json);

void main() {
  group('reconcileCollection (public, owner = me)', () {
    // Ownership predicate for a `listings`-shaped doc: writable/deletable only
    // when `by == me`.
    bool ownedByMe(Map<String, dynamic> j) => j['by'] == 'me';

    Map<String, dynamic> listing(String id, String by, {String title = 'Room'}) =>
        Listing(id: id, type: 'tenant-wanted', by: by, title: title, createdAt: '2026-01-01').toJson();

    test('new owned doc → toWrite', () {
      final mine = listing('a', 'me');
      final diff = reconcileCollection(
        baseline: const {},
        current: [mine],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(diff.toWrite.keys, ['a']);
      expect(diff.toDelete, isEmpty);
    });

    test('changed owned doc → toWrite', () {
      final original = listing('a', 'me', title: 'Old');
      final changed = listing('a', 'me', title: 'New');
      final diff = reconcileCollection(
        baseline: {'a': _canon(original)},
        current: [changed],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(diff.toWrite.keys, ['a']);
      expect(diff.toWrite['a']!['title'], 'New');
      expect(diff.toDelete, isEmpty);
    });

    test('unchanged owned doc → neither', () {
      final doc = listing('a', 'me');
      final diff = reconcileCollection(
        baseline: {'a': _canon(doc)},
        current: [doc],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(diff.toWrite, isEmpty);
      expect(diff.toDelete, isEmpty);
    });

    test('locally-removed owned doc → toDelete', () {
      final doc = listing('a', 'me');
      final diff = reconcileCollection(
        baseline: {'a': _canon(doc)},
        current: const [],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(diff.toWrite, isEmpty);
      expect(diff.toDelete, ['a']);
    });

    test("a doc the user doesn't own is never written or deleted", () {
      final theirs = listing('b', 'someone-else');
      // Present locally (received via listener): not written, not deleted.
      final present = reconcileCollection(
        baseline: {'b': _canon(theirs)},
        current: [theirs],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(present.toWrite, isEmpty);
      expect(present.toDelete, isEmpty);

      // Absent locally but in baseline: still never deleted (not ours).
      final removed = reconcileCollection(
        baseline: {'b': _canon(theirs)},
        current: const [],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(removed.toWrite, isEmpty);
      expect(removed.toDelete, isEmpty);
    });

    test('mixed batch writes only my new/changed docs, deletes only my removed doc', () {
      final mineUnchanged = listing('a', 'me', title: 'Keep');
      final mineChanged = listing('c', 'me', title: 'Edited');
      final theirs = listing('b', 'someone-else');
      final diff = reconcileCollection(
        baseline: {
          'a': _canon(mineUnchanged),
          'b': _canon(theirs),
          'c': _canon(listing('c', 'me', title: 'Original')),
          'd': _canon(listing('d', 'me')), // mine, removed locally
        },
        current: [mineUnchanged, theirs, mineChanged],
        canWrite: ownedByMe,
        canDelete: ownedByMe,
      );
      expect(diff.toWrite.keys, ['c']);
      expect(diff.toDelete, ['d']);
    });
  });

  group('reconcileCollection (notifications: create by anyone, delete by recipient)', () {
    const me = 'me';
    bool canWrite(Map<String, dynamic> j) => true; // any signed-in user may create
    bool canDelete(Map<String, dynamic> j) => j['forUserId'] == me;

    Map<String, dynamic> notif(String id, String forUserId) => AppNotification(
          id: id,
          kind: 'bill_due',
          title: 't',
          body: 'b',
          at: '2026-01-01T00:00:00',
          forUserId: forUserId,
        ).toJson();

    test('a notification I create for another user is written', () {
      final forOther = notif('n1', 'other');
      final diff = reconcileCollection(
        baseline: const {},
        current: [forOther],
        canWrite: canWrite,
        canDelete: canDelete,
      );
      expect(diff.toWrite.keys, ['n1']);
    });

    test('a notification addressed to another user is never deleted by me', () {
      final forOther = notif('n1', 'other');
      final diff = reconcileCollection(
        baseline: {'n1': _canon(forOther)},
        current: const [], // dropped from my local list
        canWrite: canWrite,
        canDelete: canDelete,
      );
      expect(diff.toDelete, isEmpty);
    });

    test('my own notification removed locally is deleted', () {
      final mine = notif('n2', me);
      final diff = reconcileCollection(
        baseline: {'n2': _canon(mine)},
        current: const [],
        canWrite: canWrite,
        canDelete: canDelete,
      );
      expect(diff.toDelete, ['n2']);
    });
  });

  group('participants derived index on private models', () {
    test('ListingInterest participants = [from, to], deduped, empties dropped', () {
      final i = ListingInterest(id: 'i1', listingId: 'l1', from: 'u1', to: 'u2', createdAt: 'x').toJson();
      expect((i['participants'] as List).toSet(), {'u1', 'u2'});

      final self = ListingInterest(id: 'i2', listingId: 'l1', from: 'u1', to: 'u1', createdAt: 'x').toJson();
      expect(self['participants'], ['u1']);

      final oneEmpty = ListingInterest(id: 'i3', listingId: 'l1', from: 'u1', to: '', createdAt: 'x').toJson();
      expect(oneEmpty['participants'], ['u1']);
    });

    test('PostMessage participants = [from, to]', () {
      final m = PostMessage(id: 'm1', listingId: 'l1', from: 'a', to: 'b', at: 'x').toJson();
      expect((m['participants'] as List).toSet(), {'a', 'b'});
    });

    test('Inspection participants = [requestedBy, to]', () {
      final ins = Inspection(id: 'ins1', requestedBy: 'r', to: 't', date: 'x', createdAt: 'x').toJson();
      expect((ins['participants'] as List).toSet(), {'r', 't'});
    });

    test('EssentialBooking participants = [requestedBy, businessOwnerId]', () {
      final b = EssentialBooking(
        id: 'b1',
        listingId: 'l1',
        requestedBy: 'client',
        businessOwnerId: 'owner',
        date: 'x',
        createdAt: 'x',
        updatedAt: 'x',
      ).toJson();
      expect((b['participants'] as List).toSet(), {'client', 'owner'});
    });

    test('participants is write-only: fromJson ignores it and round-trips', () {
      final original = ListingInterest(id: 'i1', listingId: 'l1', from: 'u1', to: 'u2', createdAt: 'x');
      final decoded = ListingInterest.fromJson(jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>);
      expect(decoded.from, 'u1');
      expect(decoded.to, 'u2');
      // Recomputed identically on re-serialization.
      expect((decoded.toJson()['participants'] as List).toSet(), {'u1', 'u2'});
    });
  });
}
