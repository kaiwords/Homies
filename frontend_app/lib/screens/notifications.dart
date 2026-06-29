import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HomiesScope.of(context).seedContextualNotifs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final prefs = state.notifPrefs;
    final uid = state.currentUser?.id ?? '';
    final myNotifs = state.appNotifications.where((n) => n.forUserId == uid).toList();
    final unreadCount = myNotifs.where((n) => !n.isRead).length;

    void toggle(bool Function(NotificationPrefs p) getter, void Function(NotificationPrefs p, bool v) setter) {
      state.mutate(() => setter(prefs, !getter(prefs)));
      NotificationService.scheduleFromState(state);
    }

    void setHour(int hour) {
      state.mutate(() => prefs.hour = hour);
      NotificationService.scheduleFromState(state);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const PageHead(
            title: 'Notifications',
            subtitle: 'Your inbox and reminder settings.',
          ),

          // ── Inbox ─────────────────────────────────────────────────────────
          if (myNotifs.isNotEmpty) ...[
            Row(children: [
              Expanded(
                child: _SectionLabel(
                  unreadCount > 0 ? 'INBOX  ·  $unreadCount unread' : 'INBOX',
                ),
              ),
              if (unreadCount > 0)
                TextButton(
                  onPressed: state.markNotificationsRead,
                  child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                ),
              TextButton(
                onPressed: () => setState(() => state.clearAppNotifications()),
                child: const Text('Clear', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              ),
            ]),
            for (final n in myNotifs) _AlertTile(notif: n),
            const SizedBox(height: 24),
          ] else ...[
            _EmptyInbox(),
            const SizedBox(height: 24),
          ],

          // ── Reminder settings ─────────────────────────────────────────────
          _SectionLabel('REMIND ME ABOUT'),
          _ToggleCard(
            icon: Icons.home_outlined,
            iconColor: HomiesColors.warn,
            label: 'Rent due',
            description: 'On the first day of each rent period if you haven\'t paid yet.',
            value: prefs.rent,
            onChanged: (v) => toggle((p) => p.rent, (p, v) => p.rent = v),
          ),
          _ToggleCard(
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xFF3182CE),
            label: 'Bills due',
            description: 'The day before each unpaid bill\'s due date.',
            value: prefs.bills,
            onChanged: (v) => toggle((p) => p.bills, (p, v) => p.bills = v),
          ),
          _ToggleCard(
            icon: Icons.cleaning_services_outlined,
            iconColor: HomiesColors.ok,
            label: 'Chores due',
            description: 'The day before your assigned cleaning task is due.',
            value: prefs.chores,
            onChanged: (v) => toggle((p) => p.chores, (p, v) => p.chores = v),
          ),
          _ToggleCard(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF805AD5),
            label: 'Chore swap requests',
            description: 'When a housemate asks to swap a cleaning task with you.',
            value: prefs.parties,
            onChanged: (v) => toggle((p) => p.parties, (p, v) => p.parties = v),
          ),

          const SizedBox(height: 20),

          // ── Reminder time ─────────────────────────────────────────────────
          _SectionLabel('REMINDER TIME'),
          Container(
            decoration: BoxDecoration(
              color: HomiesColors.surface,
              border: Border.all(color: HomiesColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Icon(Icons.access_time_outlined, size: 20, color: HomiesColors.textDim),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Send reminders at', style: TextStyle(fontSize: 14, color: HomiesColors.text)),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: prefs.hour,
                  style: const TextStyle(fontSize: 14, color: HomiesColors.accent, fontWeight: FontWeight.w600),
                  items: [
                    for (var h = 6; h <= 22; h++)
                      DropdownMenuItem(value: h, child: Text(_hourLabel(h))),
                  ],
                  onChanged: (h) { if (h != null) setHour(h); },
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reschedule all notifications'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HomiesColors.accent,
                side: const BorderSide(color: HomiesColors.accentBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await NotificationService.scheduleFromState(state);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications rescheduled.'), duration: Duration(seconds: 2)),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Notifications fire on this device only. Other housemates manage their own settings.',
            style: TextStyle(fontSize: 12, color: HomiesColors.textFaint),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  static String _hourLabel(int h) {
    if (h == 0) return '12:00 am';
    if (h == 12) return '12:00 pm';
    return h < 12 ? '$h:00 am' : '${h - 12}:00 pm';
  }
}

// ─── Kind metadata ────────────────────────────────────────────────────────────

({IconData icon, Color color}) _kindMeta(String kind) => switch (kind) {
  'rent_due' || 'rent_reminder'  => (icon: Icons.home_outlined,                     color: HomiesColors.warn),
  'payment_request'              => (icon: Icons.payments_outlined,                  color: const Color(0xFF3182CE)),
  'bill_due'                     => (icon: Icons.receipt_long_outlined,              color: const Color(0xFF3182CE)),
  'complaint'                    => (icon: Icons.report_outlined,                    color: HomiesColors.danger),
  'swap_request'                 => (icon: Icons.swap_horiz_rounded,                 color: const Color(0xFF805AD5)),
  'chore_due'                    => (icon: Icons.cleaning_services_outlined,         color: HomiesColors.ok),
  'lease_review'                 => (icon: Icons.verified_user_outlined,             color: const Color(0xFF805AD5)),
  'bond'                         => (icon: Icons.account_balance_wallet_outlined,    color: HomiesColors.warn),
  _                              => (icon: Icons.notifications_outlined,             color: HomiesColors.accent),
};

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: HomiesColors.textFaint,
            letterSpacing: 0.7,
          ),
        ),
      );
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.notifications_none_outlined, size: 26, color: HomiesColors.accent),
        ),
        const SizedBox(height: 12),
        const Text('All caught up', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'Payments, rent reminders, complaints and chore swaps will show up here.',
          style: TextStyle(fontSize: 13, color: HomiesColors.textDim, height: 1.4),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AppNotification notif;
  const _AlertTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final meta = _kindMeta(notif.kind);
    final color = meta.color;
    final unread = !notif.isRead;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread ? color.withValues(alpha: 0.07) : HomiesColors.surface,
        border: Border.all(color: unread ? color.withValues(alpha: 0.28) : HomiesColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: unread ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(meta.icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(
                  notif.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                    color: HomiesColors.text,
                  ),
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ]),
            const SizedBox(height: 3),
            Text(notif.body, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.4)),
            const SizedBox(height: 5),
            Text(
              fmtRelative(notif.at),
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.3)),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
