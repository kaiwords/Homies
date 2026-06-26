import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final prefs = state.notifPrefs;

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHead(
              title: 'Notifications',
              subtitle: 'Choose what Homies reminds you about and when.',
            ),

            // ── Reminder types ───────────────────────────────────────────────
            _SectionLabel('REMIND ME ABOUT'),
            _ToggleCard(
              icon: Icons.home_outlined,
              iconColor: HomiesColors.accent,
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
              icon: Icons.celebration_outlined,
              iconColor: const Color(0xFF805AD5),
              label: 'Party reminders',
              description: 'Morning of any scheduled house party or event.',
              value: prefs.parties,
              onChanged: (v) => toggle((p) => p.parties, (p, v) => p.parties = v),
            ),

            const SizedBox(height: 20),

            // ── Reminder time ────────────────────────────────────────────────
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
                  child: Text(
                    'Send reminders at',
                    style: TextStyle(fontSize: 14, color: HomiesColors.text),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: prefs.hour,
                    style: const TextStyle(fontSize: 14, color: HomiesColors.accent, fontWeight: FontWeight.w600),
                    items: [
                      for (var h = 6; h <= 22; h++)
                        DropdownMenuItem(
                          value: h,
                          child: Text(_hourLabel(h)),
                        ),
                    ],
                    onChanged: (h) { if (h != null) setHour(h); },
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Reschedule button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reschedule all notifications'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomiesColors.accent,
                  side: const BorderSide(color: HomiesColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await NotificationService.scheduleFromState(state);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications rescheduled.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Notifications fire on this device only. Other housemates manage their own notification settings.',
              style: TextStyle(fontSize: 12, color: HomiesColors.textFaint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _hourLabel(int h) {
    if (h == 0) return '12:00 am';
    if (h == 12) return '12:00 pm';
    return h < 12 ? '$h:00 am' : '${h - 12}:00 pm';
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: HomiesColors.textFaint,
          letterSpacing: 0.6,
        ),
      ),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: HomiesColors.accent,
        ),
      ),
    );
  }
}
