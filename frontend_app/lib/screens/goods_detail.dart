import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/media.dart';
import '../widgets/avatar.dart';
import '../widgets/listing_review_section.dart';
import '../widgets/ui_kit.dart';
import 'marketplace.dart' show goodsCatIcon, goodsCatLabel, goodsConditionLabel;
import 'marketplace_thread.dart';

String _fmtPrice(double price) => '\$${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';

/// Full detail view for a single Marketplace (secondhand goods) post — the
/// grid card in marketplace.dart only shows title/price/condition, not the
/// description, so tapping a card opens this to read the rest and (for
/// non-owners) rate the seller, or (for the owner) rate whoever's messaged
/// them about it.
class GoodsListingDetailScreen extends StatelessWidget {
  final GoodsListing listing;
  const GoodsListingDetailScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final mine = listing.postedBy == cu.id;
    final seller = state.findUser(listing.postedBy);
    final sold = listing.status == 'sold';

    // Distinct people who've messaged about this listing ("buyers"), most
    // recently active first.
    final lastMessageAt = <String, String>{};
    for (final m in state.postMessages) {
      if (m.listingId != listing.id) continue;
      final otherId = m.from == listing.postedBy ? m.to : (m.to == listing.postedBy ? m.from : null);
      if (otherId == null || otherId.isEmpty) continue;
      if (!lastMessageAt.containsKey(otherId) || m.at.compareTo(lastMessageAt[otherId]!) > 0) {
        lastMessageAt[otherId] = m.at;
      }
    }
    final buyerIds = lastMessageAt.keys.toList()..sort((a, b) => lastMessageAt[b]!.compareTo(lastMessageAt[a]!));

    return Scaffold(
      appBar: AppBar(title: Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (listing.photos.isEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(color: HomiesColors.surface2, borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Icon(goodsCatIcon(listing.category), size: 40, color: HomiesColors.textFaint),
              )
            else
              SizedBox(
                height: 220,
                child: PageView(
                  children: [
                    for (final p in listing.photos)
                      Builder(builder: (_) {
                        final bytes = decodeAttachment(p);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: bytes != null
                              ? Image.memory(bytes, fit: BoxFit.cover, width: double.infinity)
                              : Container(color: HomiesColors.surface2),
                        );
                      }),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(listing.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              if (sold) ...[
                const SizedBox(width: 8),
                const HomiesChip('SOLD', tone: ChipTone.danger),
              ],
            ]),
            const SizedBox(height: 4),
            Text(_fmtPrice(listing.price),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomiesColors.accent)),
            const SizedBox(height: 4),
            Text(
              listing.location == null
                  ? '${goodsCatLabel(listing.category)} · ${goodsConditionLabel(listing.condition)}'
                  : '${goodsCatLabel(listing.category)} · ${goodsConditionLabel(listing.condition)} · ${listing.location}',
              style: const TextStyle(fontSize: 13, color: HomiesColors.textDim),
            ),
            const SizedBox(height: 16),
            HomiesCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  listing.description.isEmpty ? 'No description provided.' : listing.description,
                  style: const TextStyle(fontSize: 13, color: HomiesColors.textDim, height: 1.5),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            HomiesCard(
              child: Row(children: [
                Avatar(user: seller),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(seller?.name ?? 'Seller',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                if (!mine)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MarketplaceThreadScreen(listing: listing, otherUserId: listing.postedBy),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: const Text('Chat', style: TextStyle(fontSize: 12)),
                  ),
              ]),
            ),
            if (mine) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => state.mutate(() => listing.status = sold ? 'available' : 'sold'),
                icon: Icon(sold ? Icons.undo_rounded : Icons.check_circle_outline_rounded, size: 16),
                label: Text(sold ? 'Mark as available' : 'Mark as sold'),
              ),
            ],
            const SizedBox(height: 20),
            if (!mine)
              ListingReviewSection(
                listingId: listing.id,
                targetUserId: listing.postedBy,
                targetUserName: seller?.name ?? 'Seller',
                roleLabel: 'seller',
              )
            else if (buyerIds.isNotEmpty) ...[
              const Text('People interested', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Rate the people who messaged you about this item.',
                  style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              const SizedBox(height: 12),
              for (final bId in buyerIds) ...[
                Builder(builder: (_) {
                  final buyer = state.findUser(bId);
                  return ListingReviewSection(
                    listingId: listing.id,
                    targetUserId: bId,
                    targetUserName: buyer?.name ?? 'Buyer',
                    roleLabel: 'buyer',
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
