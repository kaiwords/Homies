import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_kit.dart';
import 'essentials.dart' show catIcon;

({IconData icon, Color color}) _statusVisual(String status) => switch (status) {
      'confirmed' => (icon: Icons.check_circle_outline, color: HomiesColors.ok),
      'declined' || 'cancelled' => (icon: Icons.cancel_outlined, color: HomiesColors.danger),
      _ => (icon: Icons.schedule_outlined, color: HomiesColors.warn),
    };

String _frequencyLabel(String frequency) => switch (frequency) {
      'weekly' => 'Weekly',
      'fortnightly' => 'Fortnightly',
      'monthly' => 'Monthly',
      _ => frequency,
    };

/// Pending bookings first (they need a response), then earliest date first.
List<EssentialBooking> _sortedBookings(List<EssentialBooking> list) {
  final copy = [...list];
  copy.sort((a, b) {
    final aPending = a.status == 'pending' ? 0 : 1;
    final bPending = b.status == 'pending' ? 0 : 1;
    if (aPending != bPending) return aPending.compareTo(bPending);
    return a.date.compareTo(b.date);
  });
  return copy;
}

/// Shows appointment requests the current user is involved in with local
/// businesses posted under Essentials — both as the business owner
/// (incoming, confirm/decline) and as the client who requested them (mine,
/// cancel). Mirrors the Inspection request/response pattern in listings.dart.
class EssentialBookingsScreen extends StatefulWidget {
  const EssentialBookingsScreen({super.key});

  @override
  State<EssentialBookingsScreen> createState() => _EssentialBookingsScreenState();
}

class _EssentialBookingsScreenState extends State<EssentialBookingsScreen> {
  String _tab = 'incoming';

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    final incoming = _sortedBookings(state.essentialBookings.where((b) => b.businessOwnerId == cu.id).toList());
    final mine = _sortedBookings(state.essentialBookings.where((b) => b.requestedBy == cu.id).toList());
    final incomingPending = incoming.where((b) => b.status == 'pending').length;
    final shown = _tab == 'incoming' ? incoming : mine;

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Segment<String>(
              options: const ['incoming', 'mine'],
              value: _tab,
              labelFor: (t) => t == 'incoming'
                  ? 'Requests to me${incomingPending > 0 ? ' ($incomingPending)' : ''}'
                  : 'My requests',
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    title: _tab == 'incoming' ? 'No appointment requests' : 'No appointments booked',
                    body: _tab == 'incoming'
                        ? 'When a client books an appointment with one of your listings, it will show up here.'
                        : 'When you book an appointment with a business, it will show up here.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [for (final b in shown) _EssentialBookingCard(booking: b, incoming: _tab == 'incoming')],
                  ),
          ),
        ]),
      ),
    );
  }
}

class _EssentialBookingCard extends StatelessWidget {
  final EssentialBooking booking;
  final bool incoming;
  const _EssentialBookingCard({required this.booking, required this.incoming});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final b = booking;
    final other = state.findUser(incoming ? b.requestedBy : b.businessOwnerId);
    final listing = state.essentials.firstWhereOrNull((e) => e.id == b.listingId);
    final tone = b.status == 'confirmed'
        ? ChipTone.ok
        : b.status == 'declined' || b.status == 'cancelled'
            ? ChipTone.danger
            : ChipTone.warn;
    final statusVisual = _statusVisual(b.status);

    return HomiesCard(
      color: HomiesColors.surface2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar.sm(other),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                incoming
                    ? '${other?.name ?? '—'} wants to book'
                    : 'Appointment with ${listing?.businessName ?? other?.name ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (listing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: HomiesColors.accentSoft,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(catIcon(listing.category), size: 11, color: HomiesColors.accent),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(listing.businessName,
                          style: const TextStyle(color: HomiesColors.textFaint, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              Text('${fmtDate(b.date)} · ${b.slot}',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
              if (b.frequency != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.event_repeat_outlined, size: 12, color: HomiesColors.accent),
                    const SizedBox(width: 4),
                    Text('Repeats ${_frequencyLabel(b.frequency!)}',
                        style: const TextStyle(color: HomiesColors.accent, fontSize: 11, fontWeight: FontWeight.w500)),
                  ]),
                ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Icon(statusVisual.icon, size: 15, color: statusVisual.color),
            const SizedBox(height: 4),
            HomiesChip(b.status, tone: tone),
          ]),
        ]),
        if (b.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('"${b.note}"', style: const TextStyle(fontSize: 12)),
          ),
        if (incoming && b.status == 'pending')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => _respond(state, 'declined'),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _respond(state, 'confirmed'),
                child: const Text('Confirm'),
              ),
            ]),
          ),
        if (!incoming && (b.status == 'pending' || b.status == 'confirmed'))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => _respond(state, 'cancelled'),
                child: const Text('Cancel'),
              ),
            ]),
          ),
      ]),
    );
  }

  void _respond(HomiesState state, String status) {
    final now = DateTime.now().toIso8601String();
    state.mutate(() {
      booking.status = status;
      booking.updatedAt = now;
      String title;
      String forUserId;
      switch (status) {
        case 'confirmed':
        case 'declined':
          // The business owner responded — notify the client who requested it.
          title = status == 'confirmed' ? 'Appointment confirmed' : 'Appointment declined';
          forUserId = booking.requestedBy;
        case 'cancelled':
          // The client cancelled — notify the business owner.
          title = 'Appointment cancelled';
          forUserId = booking.businessOwnerId;
        default:
          return;
      }
      state.appNotifications.insert(
        0,
        AppNotification(
          id: 'ebk_${booking.id}_${status}_$now',
          kind: 'essential_booking',
          title: title,
          body: '${fmtDate(booking.date)} · ${booking.slot}',
          at: now,
          forUserId: forUserId,
        ),
      );
    });
  }
}
