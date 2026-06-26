import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../state/app_state.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channelId = 'homies_reminders';
  static const _channelName = 'Homies Reminders';
  static const _channelDesc = 'Rent, bill, chore and party reminders';

  // ID ranges per category to avoid collisions
  static const _rentBase = 1000;
  static const _billBase = 2000;
  static const _choreBase = 3000;
  static const _partyBase = 4000;

  static Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));

      // Create Android notification channel
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ));

      // Request Android 13+ notification permission
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _ready = true;
    } catch (_) {
      // Notification setup is best-effort — don't crash the app if it fails
    }
  }

  /// Cancel all pending notifications and reschedule from current state.
  static Future<void> scheduleFromState(HomiesState state) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final cu = state.currentUser;
      if (cu == null) return;
      final prefs = state.notifPrefs;

      if (prefs.rent) await _scheduleRent(state, cu.id, prefs.hour);
      if (prefs.bills) await _scheduleBills(state, cu.id, prefs.hour);
      if (prefs.chores) await _scheduleChores(state, cu.id, prefs.hour);
      if (prefs.parties) await _scheduleParties(state, prefs.hour);
    } catch (_) {
      // Silent — scheduling errors must not affect app usage
    }
  }

  static Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }

  // ─── Rent ───────────────────────────────────────────────────────────────────

  static Future<void> _scheduleRent(HomiesState state, String userId, int hour) async {
    final startStr = state.property.rentStartDate;
    if (startStr == null || startStr.isEmpty) return;
    final startDate = DateTime.tryParse(startStr);
    if (startDate == null) return;

    final periods = _upcomingPeriods(startDate, state.property.rentCadence, 8);
    for (var i = 0; i < periods.length; i++) {
      final date = periods[i];
      final periodKey = _isoDate(date);
      final alreadyPaid = state.rentPayments.any(
        (p) => p.userId == userId && p.periodStart == periodKey,
      );
      if (alreadyPaid) continue;
      await _scheduleAt(
        _rentBase + i,
        'Rent due today',
        'Your rent share is due — mark it paid in Finance.',
        _atHour(date, hour),
      );
    }
  }

  // ─── Bills ──────────────────────────────────────────────────────────────────

  static Future<void> _scheduleBills(HomiesState state, String userId, int hour) async {
    final unpaid = state.bills
        .where((b) => !(b.paidBy[userId] ?? false) && b.dueDate.isNotEmpty)
        .toList();
    for (var i = 0; i < unpaid.length && i < 30; i++) {
      final bill = unpaid[i];
      final due = DateTime.tryParse(bill.dueDate);
      if (due == null) continue;
      final remind = due.subtract(const Duration(days: 1));
      await _scheduleAt(
        _billBase + i,
        'Bill due tomorrow',
        '${bill.title} · \$${bill.amount.toStringAsFixed(2)}',
        _atHour(remind, hour),
      );
    }
  }

  // ─── Chores ─────────────────────────────────────────────────────────────────

  static Future<void> _scheduleChores(HomiesState state, String userId, int hour) async {
    final tasks = state.cleaningTasks
        .where((t) => !t.done && t.assignee == userId && t.dueDate.isNotEmpty)
        .toList();
    for (var i = 0; i < tasks.length && i < 30; i++) {
      final task = tasks[i];
      final due = DateTime.tryParse(task.dueDate);
      if (due == null) continue;
      final remind = due.subtract(const Duration(days: 1));
      await _scheduleAt(
        _choreBase + i,
        'Chore due tomorrow',
        task.task,
        _atHour(remind, hour),
      );
    }
  }

  // ─── Parties ────────────────────────────────────────────────────────────────

  static Future<void> _scheduleParties(HomiesState state, int hour) async {
    final upcoming = state.parties
        .where((p) => p.status != 'cancelled' && p.date.isNotEmpty)
        .toList();
    for (var i = 0; i < upcoming.length && i < 20; i++) {
      final party = upcoming[i];
      final date = DateTime.tryParse(party.date);
      if (date == null) continue;
      await _scheduleAt(
        _partyBase + i,
        'Party today: ${party.title}',
        'Starting at ${party.time} — don\'t forget!',
        _atHour(date, hour),
      );
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  static Future<void> _scheduleAt(int id, String title, String body, DateTime when) async {
    if (when.isBefore(DateTime.now())) return;
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzWhen,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static List<DateTime> _upcomingPeriods(DateTime start, String cadence, int count) {
    final now = DateTime.now();
    final results = <DateTime>[];
    var current = start;
    var guard = 0;
    while (guard++ < 5000) {
      if (!current.isBefore(DateTime(now.year, now.month, now.day))) {
        results.add(current);
        if (results.length >= count) break;
      }
      current = _addCadence(current, cadence);
    }
    return results;
  }

  static DateTime _addCadence(DateTime d, String cadence) {
    switch (cadence) {
      case 'fortnightly':
        return d.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(d.year, d.month + 1, d.day);
      default: // weekly
        return d.add(const Duration(days: 7));
    }
  }

  static DateTime _atHour(DateTime date, int hour) =>
      DateTime(date.year, date.month, date.day, hour);

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
