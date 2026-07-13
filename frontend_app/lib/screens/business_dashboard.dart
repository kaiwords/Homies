import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';
import 'essentials.dart' show catIcon, catLabel;
import 'marketplace.dart' show goodsCatIcon, goodsCatLabel;

/// Distinct non-owner participant IDs across [state.postMessages] for a given
/// listing — i.e. how many different people have messaged the business about
/// it. This is the mirror image of _essentialConversations/_goodsConversations
/// (which are scoped to the current user as a *participant*): here we're the
/// listing owner, filtering by listingId across every participant.
int inquiriesForListing(HomiesState state, String listingId, String ownerId) {
  final others = <String>{};
  for (final m in state.postMessages) {
    if (m.listingId != listingId) continue;
    if (m.from == ownerId) {
      if (m.to.isNotEmpty) others.add(m.to);
    } else if (m.to == ownerId) {
      if (m.from.isNotEmpty) others.add(m.from);
    }
  }
  return others.length;
}

class BusinessDashboardScreen extends StatelessWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser!;
    final myEssentials = state.essentials.where((e) => e.postedBy == user.id).toList();
    final myGoods = state.goodsListings.where((g) => g.postedBy == user.id).toList();

    final totalViews = myEssentials.fold<int>(0, (sum, e) => sum + e.viewedBy.length) +
        myGoods.fold<int>(0, (sum, g) => sum + g.viewedBy.length);
    final totalInquiries =
        myEssentials.fold<int>(0, (sum, e) => sum + inquiriesForListing(state, e.id, user.id)) +
            myGoods.fold<int>(0, (sum, g) => sum + inquiriesForListing(state, g.id, user.id));

    final hasListings = myEssentials.isNotEmpty || myGoods.isNotEmpty;
    final isBusiness = user.isBusiness;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          // Header
          HomiesCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(isBusiness ? '🏪' : '📊', style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isBusiness && (user.businessName ?? '').isNotEmpty ? user.businessName! : user.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: HomiesColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(isBusiness ? 'Your business' : 'Your listings & analytics',
                      style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                ]),
              ),
              if (isBusiness)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: HomiesColors.textDim),
                  tooltip: 'Edit business name',
                  onPressed: () => _showEditNameSheet(context, state, user),
                ),
            ]),
          ),

          const SizedBox(height: 12),

          // Totals row — same "headline stats" treatment as the member
          // dashboard's Quick stats card (one HomiesCard wrapping a StatRow
          // of StatTiles) so this reads as the page's key numbers at a glance.
          HomiesCard(
            child: StatRow(tiles: [
              StatTile(label: 'Total views', value: '$totalViews'),
              StatTile(label: 'Total inquiries', value: '$totalInquiries'),
            ]),
          ),

          const SizedBox(height: 20),

          if (!hasListings)
            const _EmptyDashboard()
          else ...[
            const _SectionHeader('Your Essentials listings'),
            if (myEssentials.isEmpty)
              const EmptyState(
                title: 'No Essentials listings yet',
                body: 'Post one from Essentials to start tracking views and inquiries.',
              )
            else
              for (final e in myEssentials)
                _ListingStatCard(
                  icon: catIcon(e.category),
                  title: e.businessName,
                  subtitle: catLabel(e.category),
                  views: e.viewedBy.length,
                  inquiries: inquiriesForListing(state, e.id, user.id),
                ),

            const SizedBox(height: 20),
            const _SectionHeader('Your Marketplace listings'),
            if (myGoods.isEmpty)
              const EmptyState(
                title: 'No Marketplace listings yet',
                body: 'Post one from Marketplace to start tracking views and inquiries.',
              )
            else
              for (final g in myGoods)
                _ListingStatCard(
                  icon: goodsCatIcon(g.category),
                  title: g.title,
                  subtitle: goodsCatLabel(g.category),
                  views: g.viewedBy.length,
                  inquiries: inquiriesForListing(state, g.id, user.id),
                ),
          ],
        ],
      ),
    );
  }

  void _showEditNameSheet(BuildContext context, HomiesState state, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditBusinessNameSheet(state: state, user: user),
    );
  }
}

// ─── Section header / empty states ───────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HomiesColors.text)),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            "You haven't posted anything yet",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: HomiesColors.text),
          ),
          const SizedBox(height: 8),
          const Text(
            'Post your first listing from Essentials or Marketplace to start tracking views and inquiries.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: HomiesColors.textDim),
          ),
        ]),
      ),
    );
  }
}

// ─── Listing stat card ────────────────────────────────────────────────────────

class _ListingStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int views;
  final int inquiries;
  const _ListingStatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.views,
    required this.inquiries,
  });

  @override
  Widget build(BuildContext context) {
    return HomiesCard(
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: HomiesColors.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: HomiesColors.text)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: HomiesColors.textDim)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.visibility_outlined, size: 13, color: HomiesColors.textFaint),
            const SizedBox(width: 4),
            Text('$views', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline, size: 13, color: HomiesColors.textFaint),
            const SizedBox(width: 4),
            Text('$inquiries', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          ]),
        ]),
      ]),
    );
  }
}

// ─── Edit business name sheet ─────────────────────────────────────────────────

class _EditBusinessNameSheet extends StatefulWidget {
  final HomiesState state;
  final User user;
  const _EditBusinessNameSheet({required this.state, required this.user});

  @override
  State<_EditBusinessNameSheet> createState() => _EditBusinessNameSheetState();
}

class _EditBusinessNameSheetState extends State<_EditBusinessNameSheet> {
  late final _ctrl = TextEditingController(text: widget.user.businessName ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _ctrl.text.trim();
    widget.state.mutate(() => widget.user.businessName = name.isEmpty ? null : name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: HomiesColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Edit business name',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomiesColors.text)),
            const SizedBox(height: 16),
            const FieldLabel('Business name'),
            TextField(controller: _ctrl, autofocus: true),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: HomiesColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    );
  }
}
