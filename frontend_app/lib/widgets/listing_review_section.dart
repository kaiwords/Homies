import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'ui_kit.dart';

/// Star-rating reviews for a specific person's role on a specific listing —
/// e.g. "rate the seller" on a Marketplace post, "rate the business" on an
/// Essentials post, or the reverse (a seller/business rating a buyer/client
/// back). One review per (listingId, fromUserId, targetUserId) triple —
/// submitting again replaces the existing one, mirroring how
/// [LeaseholderReview] works in housemates.dart.
class ListingReviewSection extends StatelessWidget {
  final String listingId;
  final String targetUserId;
  final String targetUserName;
  final String roleLabel; // e.g. 'seller', 'business', 'buyer', 'client'
  const ListingReviewSection({
    super.key,
    required this.listingId,
    required this.targetUserId,
    required this.targetUserName,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final reviews = state.listingReviews
        .where((r) => r.listingId == listingId && r.targetUserId == targetUserId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final myReview = reviews.firstWhereOrNull((r) => r.fromUserId == cu.id);
    final avg = reviews.isEmpty ? 0.0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final isSelf = cu.id == targetUserId;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reviews for the $roleLabel',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: HomiesColors.text)),
            if (reviews.isNotEmpty)
              Row(children: [
                for (int i = 1; i <= 5; i++)
                  Icon(i <= avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 14, color: const Color(0xFFF5A623)),
                const SizedBox(width: 4),
                Text('${avg.toStringAsFixed(1)} (${reviews.length})',
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textDim)),
              ])
            else
              const Text('No reviews yet', style: TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
          ]),
        ),
        if (!isSelf)
          TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => _WriteListingReviewSheet(
                listingId: listingId,
                targetUserId: targetUserId,
                targetUserName: targetUserName,
                roleLabel: roleLabel,
                existing: myReview,
              ),
            ),
            child: Text(myReview == null ? 'Rate' : 'Edit'),
          ),
      ]),
      if (reviews.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final r in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: r.fromUserId == cu.id ? HomiesColors.accentSoft : HomiesColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: r.fromUserId == cu.id ? HomiesColors.accentBorder : HomiesColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (int i = 1; i <= 5; i++)
                  Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 13, color: const Color(0xFFF5A623)),
                const SizedBox(width: 6),
                Text(
                  r.anonymous ? 'Anonymous' : r.fromUserName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HomiesColors.textDim),
                ),
                const Spacer(),
                Text(fmtDate(r.date), style: const TextStyle(fontSize: 10, color: HomiesColors.textFaint)),
              ]),
              if (r.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.body, style: const TextStyle(fontSize: 12)),
              ],
            ]),
          ),
      ],
    ]);
  }
}

class _WriteListingReviewSheet extends StatefulWidget {
  final String listingId;
  final String targetUserId;
  final String targetUserName;
  final String roleLabel;
  final ListingReview? existing;
  const _WriteListingReviewSheet({
    required this.listingId,
    required this.targetUserId,
    required this.targetUserName,
    required this.roleLabel,
    this.existing,
  });

  @override
  State<_WriteListingReviewSheet> createState() => _WriteListingReviewSheetState();
}

class _WriteListingReviewSheetState extends State<_WriteListingReviewSheet> {
  int _rating = 3;
  bool _anon = false;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 3;
    _anon = widget.existing?.anonymous ?? false;
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: HomiesColors.textFaint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            widget.existing == null ? 'Rate ${widget.targetUserName.split(' ').first}' : 'Edit your review',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Rating'),
          const SizedBox(height: 8),
          Row(children: [
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => _rating = i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: const Color(0xFFF5A623),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          const FieldLabel('Your thoughts (optional)'),
          TextField(
            controller: _bodyCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'What went well? What could be better?'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Checkbox(
              value: _anon,
              onChanged: (v) => setState(() => _anon = v ?? false),
            ),
            const Text('Submit anonymously', style: TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                state.mutate(() {
                  state.listingReviews.removeWhere((r) =>
                      r.fromUserId == cu.id && r.listingId == widget.listingId && r.targetUserId == widget.targetUserId);
                  state.listingReviews.add(ListingReview(
                    id: 'lr-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
                    listingId: widget.listingId,
                    targetUserId: widget.targetUserId,
                    targetUserName: widget.targetUserName,
                    fromUserId: cu.id,
                    fromUserName: cu.name,
                    anonymous: _anon,
                    rating: _rating,
                    body: _bodyCtrl.text.trim(),
                    date: todayIso(),
                  ));
                });
                Navigator.pop(context);
              },
              child: Text(widget.existing == null ? 'Submit' : 'Save changes'),
            ),
          ]),
        ]),
      ),
    );
  }
}
