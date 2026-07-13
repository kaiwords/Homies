import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/listing_review_section.dart';
import '../widgets/ui_kit.dart';
import 'essential_booking.dart';
import 'essential_thread.dart';
import 'essentials.dart' show catIcon, catLabel;

/// Full detail view for a single Essentials (local business) post. The card
/// in essentials.dart already shows the description inline, but this gives
/// the listing its own page to host reviews: clients rate the business, and
/// the business rates back whoever's messaged/booked with them.
class EssentialListingDetailScreen extends StatelessWidget {
  final EssentialListing listing;
  const EssentialListingDetailScreen({super.key, required this.listing});

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final mine = listing.postedBy == cu.id;
    final business = state.findUser(listing.postedBy);
    final liked = listing.likes.contains(cu.id);

    // Distinct people who've messaged or booked with this business ("clients"),
    // most recently active first.
    final lastActivityAt = <String, String>{};
    for (final m in state.postMessages) {
      if (m.listingId != listing.id) continue;
      final otherId = m.from == listing.postedBy ? m.to : (m.to == listing.postedBy ? m.from : null);
      if (otherId == null || otherId.isEmpty) continue;
      if (!lastActivityAt.containsKey(otherId) || m.at.compareTo(lastActivityAt[otherId]!) > 0) {
        lastActivityAt[otherId] = m.at;
      }
    }
    for (final b in state.essentialBookings.where((b) => b.listingId == listing.id)) {
      if (!lastActivityAt.containsKey(b.requestedBy) || b.createdAt.compareTo(lastActivityAt[b.requestedBy]!) > 0) {
        lastActivityAt[b.requestedBy] = b.createdAt;
      }
    }
    final clientIds = lastActivityAt.keys.toList()..sort((a, b) => lastActivityAt[b]!.compareTo(lastActivityAt[a]!));

    return Scaffold(
      appBar: AppBar(title: Text(listing.businessName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Icon(catIcon(listing.category), size: 22, color: HomiesColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(listing.businessName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(catLabel(listing.category), style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                ]),
              ),
              GestureDetector(
                onTap: () => state.mutate(() {
                  if (liked) {
                    listing.likes.remove(cu.id);
                  } else {
                    listing.likes.add(cu.id);
                  }
                }),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 20, color: liked ? HomiesColors.danger : HomiesColors.textFaint),
                  if (listing.likes.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text('${listing.likes.length}', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                  ],
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Text(listing.description, style: const TextStyle(fontSize: 13, color: HomiesColors.textDim, height: 1.5)),
              ]),
            ),
            if (listing.phone != null || listing.website != null || listing.hours != null || listing.address != null) ...[
              const SizedBox(height: 12),
              HomiesCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (listing.phone != null)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      text: listing.phone!,
                      onTap: () => _launch('tel:${listing.phone!.replaceAll(RegExp(r'[^\d+]'), '')}'),
                    ),
                  if (listing.website != null)
                    _ContactRow(
                      icon: Icons.language_outlined,
                      text: listing.website!,
                      onTap: () => _launch(listing.website!.startsWith('http') ? listing.website! : 'https://${listing.website!}'),
                    ),
                  if (listing.hours != null) _ContactRow(icon: Icons.schedule_outlined, text: listing.hours!),
                  if (listing.address != null) _ContactRow(icon: Icons.place_outlined, text: listing.address!),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            HomiesCard(
              child: Row(children: [
                Avatar(user: business),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(business?.name ?? listing.businessName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (!mine) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EssentialThreadScreen(listing: listing, otherUserId: listing.postedBy),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: const Text('Chat', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: EssentialBookingModal(listing: listing),
                      ),
                    ),
                    icon: const Icon(Icons.event_outlined, size: 15),
                    label: const Text('Book', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(backgroundColor: HomiesColors.accent),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            if (!mine)
              ListingReviewSection(
                listingId: listing.id,
                targetUserId: listing.postedBy,
                targetUserName: business?.name ?? listing.businessName,
                roleLabel: 'business',
              )
            else if (clientIds.isNotEmpty) ...[
              const Text('Your consumers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Rate the people who messaged or booked with you.',
                  style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              const SizedBox(height: 12),
              for (final cId in clientIds) ...[
                Builder(builder: (_) {
                  final client = state.findUser(cId);
                  return ListingReviewSection(
                    listingId: listing.id,
                    targetUserId: cId,
                    targetUserName: client?.name ?? 'Consumer',
                    roleLabel: 'consumer',
                  );
                }),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _ContactRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: HomiesColors.textFaint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: onTap != null ? HomiesColors.accent : HomiesColors.textDim,
              decoration: onTap != null ? TextDecoration.underline : null,
            ),
          ),
        ),
      ]),
    );
    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}
