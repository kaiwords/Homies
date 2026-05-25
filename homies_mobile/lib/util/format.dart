import 'package:intl/intl.dart';

import '../state/models.dart';

final _aud = NumberFormat.currency(locale: 'en_AU', symbol: r'$', decimalDigits: 2);
final _date = DateFormat('d MMM yyyy', 'en_AU');
final _dateShort = DateFormat('d MMM', 'en_AU');

String fmtAUD(num? n) {
  if (n == null || n.isNaN) return '—';
  return _aud.format(n);
}

DateTime? parseIso(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    return DateTime.parse(iso);
  } catch (_) {
    return null;
  }
}

String fmtDate(String? iso) {
  final d = parseIso(iso);
  if (d == null) return '—';
  return _date.format(d);
}

String fmtDateShort(String? iso) {
  final d = parseIso(iso);
  if (d == null) return '—';
  return _dateShort.format(d);
}

String fmtRelative(String? iso) {
  final d = parseIso(iso);
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final days = target.difference(today).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days == -1) return 'yesterday';
  if (days > 0 && days < 7) return 'in $days days';
  if (days < 0 && days > -7) return '${days.abs()} days ago';
  return fmtDate(iso);
}

List<double> equalSplit(double total, int n) {
  if (n == 0) return [];
  final base = (total * 100 ~/ n) / 100;
  final shares = List<double>.filled(n, base);
  final remainder = ((total - base * n) * 100).round() / 100;
  if (remainder > 0) {
    shares[0] = ((shares[0] + remainder) * 100).round() / 100;
  }
  return shares;
}

int daysBetween(String? startIso, String? endIso) {
  final s = parseIso(startIso);
  final e = parseIso(endIso);
  if (s == null || e == null) return 0;
  if (e.isBefore(s)) return 0;
  return e.difference(s).inDays + 1;
}

int residentDays(User user, String periodStart, String periodEnd) {
  final start = parseIso(periodStart);
  final end = parseIso(periodEnd);
  if (start == null || end == null || end.isBefore(start)) return 0;
  final moveIn = parseIso(user.moveInDate) ?? start;
  final moveOut = parseIso(user.moveOutDate) ?? end;
  final overlapStart = moveIn.isAfter(start) ? moveIn : start;
  final overlapEnd = moveOut.isBefore(end) ? moveOut : end;
  if (overlapEnd.isBefore(overlapStart)) return 0;
  return overlapEnd.difference(overlapStart).inDays + 1;
}

Map<String, double> prorateShares(double total, List<String> participantIds, List<User> users, String? periodStart, String? periodEnd) {
  if (periodStart == null || periodEnd == null || periodStart.isEmpty || periodEnd.isEmpty) {
    final arr = equalSplit(total, participantIds.length);
    return {for (var i = 0; i < participantIds.length; i++) participantIds[i]: arr[i]};
  }
  final personDays = <String, int>{};
  int totalDays = 0;
  for (final id in participantIds) {
    final u = users.firstWhereOrNull((x) => x.id == id);
    final d = u != null ? residentDays(u, periodStart, periodEnd) : 0;
    personDays[id] = d;
    totalDays += d;
  }
  if (totalDays == 0) return {for (final id in participantIds) id: 0};
  final shares = <String, double>{};
  double running = 0;
  for (var i = 0; i < participantIds.length; i++) {
    final id = participantIds[i];
    if (i == participantIds.length - 1) {
      shares[id] = ((total - running) * 100).round() / 100;
    } else {
      final exact = total * (personDays[id] ?? 0) / totalDays;
      final rounded = (exact * 100).round() / 100;
      shares[id] = rounded;
      running += rounded;
    }
  }
  return shares;
}

bool isApprovalComplete(User? u) =>
    u != null &&
    u.docVerified &&
    u.bondPaid &&
    u.advanceRentPaid &&
    (u.acceptedRulesAt?.isNotEmpty ?? false) &&
    (u.moveInDate?.isNotEmpty ?? false);

String cadenceLabel(String c) =>
    {'weekly': 'Weekly', 'fortnightly': 'Fortnightly', 'monthly': 'Monthly'}[c] ?? c;

const Map<String, String> _cadenceFull = {
  'weekly': 'Weekly',
  'fortnightly': 'Fortnightly',
  'monthly': 'Monthly',
  'quarterly': 'Quarterly',
  'half-yearly': 'Half-yearly',
  'yearly': 'Yearly',
};

String cadenceLabelFull(String c, int? customDays) {
  if (c == 'custom') return 'Every ${customDays ?? '?'} days';
  return _cadenceFull[c] ?? c;
}

String? _shift(String? iso, String cadence, int? customDays, int sign) {
  if (iso == null || iso.isEmpty) return iso;
  final d = parseIso(iso);
  if (d == null) return iso;
  DateTime out;
  switch (cadence) {
    case 'weekly':
      out = d.add(Duration(days: 7 * sign));
      break;
    case 'fortnightly':
      out = d.add(Duration(days: 14 * sign));
      break;
    case 'monthly':
      out = DateTime(d.year, d.month + sign, d.day);
      break;
    case 'quarterly':
      out = DateTime(d.year, d.month + 3 * sign, d.day);
      break;
    case 'half-yearly':
      out = DateTime(d.year, d.month + 6 * sign, d.day);
      break;
    case 'yearly':
      out = DateTime(d.year + sign, d.month, d.day);
      break;
    case 'custom':
      out = d.add(Duration(days: (customDays ?? 0) * sign));
      break;
    default:
      return iso;
  }
  return out.toIso8601String().substring(0, 10);
}

String? addCadence(String? iso, String cadence, int? customDays) => _shift(iso, cadence, customDays, 1);
String? subtractCadence(String? iso, String cadence, int? customDays) => _shift(iso, cadence, customDays, -1);

String todayIso() => DateTime.now().toIso8601String().substring(0, 10);

String daysAheadIso(int n) =>
    DateTime.now().add(Duration(days: n)).toIso8601String().substring(0, 10);

String daysAgoIso(int n) =>
    DateTime.now().subtract(Duration(days: n)).toIso8601String().substring(0, 10);

extension FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
