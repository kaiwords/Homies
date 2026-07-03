import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';
import 'essentials.dart' show catIcon;

String _bid() => 'ebk-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

const _repeatOptions = <(String?, String)>[
  (null, "Doesn't repeat"),
  ('weekly', 'Weekly'),
  ('fortnightly', 'Fortnightly'),
  ('monthly', 'Monthly'),
];

/// Bottom-sheet form for a client to request an appointment with an
/// essentials listing's business. Submits a 'pending' EssentialBooking that
/// the business owner then confirms or declines from EssentialBookingsScreen.
class EssentialBookingModal extends StatefulWidget {
  final EssentialListing listing;
  const EssentialBookingModal({super.key, required this.listing});

  @override
  State<EssentialBookingModal> createState() => _EssentialBookingModalState();
}

class _EssentialBookingModalState extends State<EssentialBookingModal> {
  DateTime? _date;
  final _slotCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _frequency;

  @override
  void dispose() {
    _slotCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final canBook = _date != null && _slotCtrl.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: HomiesColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: HomiesColors.accentSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(catIcon(widget.listing.category), size: 16, color: HomiesColors.accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.listing.businessName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HomiesColors.text),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                'Request a time. The business confirms or declines your request.',
                style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const FieldLabel('Preferred date'),
              OutlinedButton(
                onPressed: () async {
                  final d = await pickDate(context, initial: _date);
                  if (d != null) setState(() => _date = d);
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_date == null ? 'Pick a date' : fmtDate(toIso(_date))),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Preferred time'),
              TextField(
                controller: _slotCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'e.g. 10:00 am or after 3pm'),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Note (optional)'),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Anything the business should know…'),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Repeat'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final opt in _repeatOptions)
                  GestureDetector(
                    onTap: () => setState(() => _frequency = opt.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _frequency == opt.$1 ? HomiesColors.accent : HomiesColors.surface2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _frequency == opt.$1 ? HomiesColors.accent : HomiesColors.border,
                        ),
                      ),
                      child: Text(opt.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _frequency == opt.$1 ? Colors.white : HomiesColors.text)),
                    ),
                  ),
              ]),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: !canBook
                    ? null
                    : () {
                        final now = DateTime.now().toIso8601String();
                        final booking = EssentialBooking(
                          id: _bid(),
                          listingId: widget.listing.id,
                          requestedBy: cu.id,
                          businessOwnerId: widget.listing.postedBy,
                          date: toIso(_date)!,
                          slot: _slotCtrl.text.trim(),
                          note: _noteCtrl.text.trim(),
                          createdAt: now,
                          updatedAt: now,
                          frequency: _frequency,
                        );
                        state.mutate(() {
                          state.essentialBookings.insert(0, booking);
                          state.appNotifications.insert(
                            0,
                            AppNotification(
                              id: 'ebk_${booking.id}_requested',
                              kind: 'essential_booking',
                              title: 'New appointment request',
                              body: '${cu.name} requested ${fmtDate(booking.date)} · ${booking.slot} at ${widget.listing.businessName}',
                              at: now,
                              forUserId: booking.businessOwnerId,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: HomiesColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Request appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
