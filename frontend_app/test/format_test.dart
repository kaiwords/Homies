import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:homies_mobile/state/models.dart';
import 'package:homies_mobile/util/format.dart';

User _user({String id = 'u1', String? moveIn, String? moveOut}) => User(
      id: id,
      name: 'Test User',
      initials: 'TU',
      role: 'tenant',
      email: 't@example.com',
      phone: '',
      moveInDate: moveIn,
      moveOutDate: moveOut,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en_AU', null);
  });

  group('fmtAUD', () {
    test('formats amounts with thousands separator and two decimals', () {
      expect(fmtAUD(1234.5), r'$1,234.50');
      expect(fmtAUD(0), r'$0.00');
    });

    test('returns em dash for null and NaN', () {
      expect(fmtAUD(null), '—');
      expect(fmtAUD(double.nan), '—');
    });
  });

  group('parseIso / fmtDate', () {
    test('parses valid ISO dates', () {
      expect(parseIso('2026-07-18'), DateTime(2026, 7, 18));
    });

    test('returns null for null, empty, and garbage input', () {
      expect(parseIso(null), isNull);
      expect(parseIso(''), isNull);
      expect(parseIso('not-a-date'), isNull);
    });

    test('fmtDate renders en_AU style and dashes for bad input', () {
      expect(fmtDate('2026-01-05'), '5 Jan 2026');
      expect(fmtDate(null), '—');
      expect(fmtDate('garbage'), '—');
    });
  });

  group('fmtChatDay', () {
    test('labels today and yesterday', () {
      expect(fmtChatDay(todayIso()), 'Today');
      expect(fmtChatDay(daysAgoIso(1)), 'Yesterday');
    });

    test('falls back to a date for older days and empty for bad input', () {
      expect(fmtChatDay('2020-03-01'), '1 Mar 2020');
      expect(fmtChatDay(null), '');
    });
  });

  group('fmtDuration', () {
    test('formats milliseconds as m:ss', () {
      expect(fmtDuration(65000), '1:05');
      expect(fmtDuration(5000), '0:05');
      expect(fmtDuration(600000), '10:00');
    });

    test('clamps null, zero, and negatives to 0:00', () {
      expect(fmtDuration(null), '0:00');
      expect(fmtDuration(0), '0:00');
      expect(fmtDuration(-100), '0:00');
    });
  });

  group('fmtRelative', () {
    test('labels nearby days', () {
      expect(fmtRelative(todayIso()), 'today');
      expect(fmtRelative(daysAheadIso(1)), 'tomorrow');
      expect(fmtRelative(daysAgoIso(1)), 'yesterday');
      expect(fmtRelative(daysAheadIso(3)), 'in 3 days');
      expect(fmtRelative(daysAgoIso(3)), '3 days ago');
    });

    test('rolls up to weeks and months', () {
      expect(fmtRelative(daysAheadIso(14)), 'in 2 weeks');
      expect(fmtRelative(daysAgoIso(14)), '2 weeks ago');
      expect(fmtRelative(daysAheadIso(60)), 'in 2 months');
    });

    test('returns empty string for bad input', () {
      expect(fmtRelative(null), '');
      expect(fmtRelative('garbage'), '');
    });
  });

  group('equalSplit', () {
    test('splits evenly when divisible', () {
      expect(equalSplit(90, 3), [30.0, 30.0, 30.0]);
    });

    test('gives the rounding remainder to the first share and preserves the total', () {
      final shares = equalSplit(100, 3);
      expect(shares, [33.34, 33.33, 33.33]);
      expect(shares.reduce((a, b) => a + b), closeTo(100, 0.001));
    });

    test('returns empty list for zero participants', () {
      expect(equalSplit(100, 0), isEmpty);
    });
  });

  group('daysBetween', () {
    test('is inclusive of both endpoints', () {
      expect(daysBetween('2026-01-01', '2026-01-01'), 1);
      expect(daysBetween('2026-01-01', '2026-01-07'), 7);
    });

    test('returns 0 for reversed or invalid ranges', () {
      expect(daysBetween('2026-01-07', '2026-01-01'), 0);
      expect(daysBetween(null, '2026-01-01'), 0);
      expect(daysBetween('2026-01-01', 'bad'), 0);
    });
  });

  group('residentDays', () {
    test('full period when no move dates set', () {
      expect(residentDays(_user(), '2026-01-01', '2026-01-31'), 31);
    });

    test('clips to move-in and move-out dates', () {
      expect(
        residentDays(_user(moveIn: '2026-01-16'), '2026-01-01', '2026-01-31'),
        16,
      );
      expect(
        residentDays(_user(moveIn: '2026-01-01', moveOut: '2026-01-10'), '2026-01-01', '2026-01-31'),
        10,
      );
    });

    test('returns 0 when residency does not overlap the period', () {
      expect(
        residentDays(_user(moveIn: '2026-03-01'), '2026-01-01', '2026-01-31'),
        0,
      );
    });
  });

  group('prorateShares', () {
    test('falls back to equal split when no period given', () {
      final users = [_user(id: 'a'), _user(id: 'b')];
      final shares = prorateShares(100, ['a', 'b'], users, null, null);
      expect(shares['a']! + shares['b']!, closeTo(100, 0.001));
      expect(shares['a'], shares['b']);
    });

    test('prorates by resident days and sums exactly to the total', () {
      // 'a' resident the full 30 days of April, 'b' only the last 15.
      final users = [
        _user(id: 'a'),
        _user(id: 'b', moveIn: '2026-04-16'),
      ];
      final shares = prorateShares(90, ['a', 'b'], users, '2026-04-01', '2026-04-30');
      expect(shares['a']! + shares['b']!, closeTo(90, 0.001));
      expect(shares['a']!, greaterThan(shares['b']!));
      // 30/45 vs 15/45 of $90 = $60 vs $30
      expect(shares['a'], 60.0);
      expect(shares['b'], 30.0);
    });

    test('returns zeros when nobody was resident in the period', () {
      final users = [_user(id: 'a', moveIn: '2027-01-01')];
      final shares = prorateShares(100, ['a'], users, '2026-01-01', '2026-01-31');
      expect(shares, {'a': 0});
    });
  });

  group('isApprovalComplete', () {
    test('true only when all approval requirements are met', () {
      final u = _user(moveIn: '2026-01-01')
        ..docVerified = true
        ..bondPaid = true
        ..advanceRentPaid = true
        ..acceptedRulesAt = '2026-01-01T00:00:00';
      expect(isApprovalComplete(u), isTrue);
    });

    test('false when any requirement is missing or user is null', () {
      expect(isApprovalComplete(null), isFalse);
      final noBond = _user(moveIn: '2026-01-01')
        ..docVerified = true
        ..advanceRentPaid = true
        ..acceptedRulesAt = '2026-01-01T00:00:00';
      expect(isApprovalComplete(noBond), isFalse);
    });
  });

  group('cadence maths', () {
    test('addCadence advances by the cadence', () {
      expect(addCadence('2026-01-15', 'weekly', null), '2026-01-22');
      expect(addCadence('2026-01-15', 'fortnightly', null), '2026-01-29');
      expect(addCadence('2026-01-15', 'monthly', null), '2026-02-15');
      expect(addCadence('2026-01-15', 'quarterly', null), '2026-04-15');
      expect(addCadence('2026-01-15', 'yearly', null), '2027-01-15');
      expect(addCadence('2026-01-15', 'custom', 10), '2026-01-25');
    });

    test('subtractCadence is the inverse of addCadence', () {
      expect(subtractCadence('2026-02-15', 'monthly', null), '2026-01-15');
      expect(subtractCadence('2026-01-22', 'weekly', null), '2026-01-15');
    });

    test('passes through unknown cadences and bad dates unchanged', () {
      expect(addCadence('2026-01-15', 'nonsense', null), '2026-01-15');
      expect(addCadence(null, 'weekly', null), isNull);
      expect(addCadence('', 'weekly', null), '');
    });

    test('cadenceLabelFull covers custom and unknown cadences', () {
      expect(cadenceLabelFull('monthly', null), 'Monthly');
      expect(cadenceLabelFull('custom', 9), 'Every 9 days');
      expect(cadenceLabelFull('custom', null), 'Every ? days');
      expect(cadenceLabelFull('oddball', null), 'oddball');
    });
  });

  group('FirstWhereOrNull extension', () {
    test('firstWhereOrNull returns match or null', () {
      expect([1, 2, 3].firstWhereOrNull((e) => e > 1), 2);
      expect([1, 2, 3].firstWhereOrNull((e) => e > 9), isNull);
    });

    test('lastWhereOrNull returns last match or null', () {
      expect([1, 2, 3].lastWhereOrNull((e) => e > 1), 3);
      expect(<int>[].lastWhereOrNull((e) => true), isNull);
    });
  });
}
