import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/category_prefs_sheet.dart';
import '../widgets/ui_kit.dart';
import 'essential_booking.dart';
import 'essential_bookings.dart';
import 'essential_thread.dart';

// ─── Category metadata ────────────────────────────────────────────────────────

const essentialCats = <(String, String, IconData)>[
  ('all',      'All',         Icons.grid_view_rounded),
  ('removal',  'Removal',     Icons.local_shipping_outlined),
  ('haircut',  'Haircut',     Icons.content_cut_outlined),
  ('cleaning', 'Cleaning',    Icons.cleaning_services_outlined),
  ('agency',   'Work Agency', Icons.work_outline),
  ('driving',  'Driving',     Icons.directions_car_outlined),
  ('other',    'Other',       Icons.miscellaneous_services_outlined),
];

String catLabel(String key) =>
    essentialCats.firstWhere((c) => c.$1 == key, orElse: () => ('other', 'Other', Icons.miscellaneous_services_outlined)).$2;

IconData catIcon(String key) =>
    essentialCats.firstWhere((c) => c.$1 == key, orElse: () => ('other', 'Other', Icons.miscellaneous_services_outlined)).$3;

const _catPrefsMin = 3;
const _catPrefsMax = 10;

/// A small uppercase section header with a trailing divider, used to break
/// long forms (like the post-a-service sheet) into scannable groups.
Widget _formSection(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.6)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ]),
    );

/// The category chips actually shown to this user: everything, until they've
/// picked a preference — then just "All" plus their chosen categories.
List<(String, String, IconData)> _visibleCats(HomiesState state) {
  if (state.essentialCategoryPrefs.isEmpty) return essentialCats;
  return [
    essentialCats.first, // 'all'
    ...essentialCats.where((c) => state.essentialCategoryPrefs.contains(c.$1)),
  ];
}

String _pid() => 'es-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

List<({EssentialListing listing, String otherId, PostMessage last})> _essentialConversations(
    HomiesState state, User cu) {
  // Single pass over postMessages (O(M)) instead of nested-looping essentials
  // x partners x postMessages with a re-filter per partner — that used to
  // recompute from scratch on every rebuild, including remote sync events
  // now that essentials/postMessages sync live via Firestore, which showed
  // up as UI lag. This also fixes a correctness bug the old version had:
  // it looked up threads via (e.postedBy, partner) instead of (cu.id,
  // partner), so a client (not the listing owner) chatting with a business
  // would never see that conversation in their own Messages list — only the
  // owner's side ever worked.
  final latest = <String, Map<String, PostMessage>>{}; // listingId -> otherId -> latest message
  for (final m in state.postMessages) {
    final String otherId;
    if (m.from == cu.id) {
      otherId = m.to;
    } else if (m.to == cu.id) {
      otherId = m.from;
    } else {
      continue;
    }
    final byOther = latest.putIfAbsent(m.listingId, () => {});
    final existing = byOther[otherId];
    if (existing == null || m.at.compareTo(existing.at) > 0) {
      byOther[otherId] = m;
    }
  }
  if (latest.isEmpty) return const [];
  final essentialsById = {for (final e in state.essentials) e.id: e};
  final out = <({EssentialListing listing, String otherId, PostMessage last})>[];
  latest.forEach((listingId, byOther) {
    final listing = essentialsById[listingId];
    if (listing == null) return; // not an essentials listing (e.g. a marketplace room), or deleted
    byOther.forEach((otherId, last) => out.add((listing: listing, otherId: otherId, last: last)));
  });
  out.sort((a, b) => b.last.at.compareTo(a.last.at));
  return out;
}

void _openEssentialThread(BuildContext context, EssentialListing listing, String otherUserId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => EssentialThreadScreen(listing: listing, otherUserId: otherUserId)),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class EssentialsScreen extends StatefulWidget {
  const EssentialsScreen({super.key});

  @override
  State<EssentialsScreen> createState() => _EssentialsScreenState();
}

class _EssentialsScreenState extends State<EssentialsScreen> {
  String _filter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final user = state.currentUser!;
    final all = state.essentials;
    final query = _searchCtrl.text.trim().toLowerCase();
    final shown = all.where((e) {
      if (_filter != 'all' && e.category != _filter) return false;
      if (query.isNotEmpty &&
          !e.businessName.toLowerCase().contains(query) &&
          !e.description.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    final convs = _essentialConversations(state, user);
    final pendingBookings =
        state.essentialBookings.where((b) => b.businessOwnerId == user.id && b.status == 'pending').length;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(
                      'Essentials',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: HomiesColors.text,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Local services posted by the community.',
                      style: TextStyle(fontSize: 13, color: HomiesColors.textDim),
                    ),
                  ]),
                ),
                const SizedBox(width: 4),
                _BadgeIconButton(
                  icon: Icons.chat_bubble_outline,
                  tooltip: 'Messages',
                  count: convs.length,
                  onPressed: () => _openEssentialConversations(context, convs, state, user),
                ),
                _BadgeIconButton(
                  icon: Icons.event_outlined,
                  tooltip: 'My bookings',
                  count: pendingBookings,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EssentialBookingsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showPostSheet(context, state, user),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Post', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiesColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // Search
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search by business name…',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
          ),

          // Category chips
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final cat in _visibleCats(state))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = cat.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filter == cat.$1 ? HomiesColors.accent : HomiesColors.surface2,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _filter == cat.$1 ? HomiesColors.accent : HomiesColors.border,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(cat.$3, size: 13,
                              color: _filter == cat.$1 ? Colors.white : HomiesColors.textDim),
                          const SizedBox(width: 5),
                          Text(
                            cat.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _filter == cat.$1 ? Colors.white : HomiesColors.text,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _showCategoryPrefsSheet(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: HomiesColors.surface2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: HomiesColors.border),
                    ),
                    child: const Icon(Icons.tune, size: 15, color: HomiesColors.textDim),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Listings
          Expanded(
            child: shown.isEmpty
                ? _EmptyState(
                    filter: _filter,
                    query: query,
                    onPost: () => _showPostSheet(context, state, user),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final listing = shown[shown.length - 1 - i]; // newest first
                      return _ListingCard(
                        listing: listing,
                        currentUserId: user.id,
                        onLike: () => _toggleLike(state, listing, user.id),
                        onDelete: listing.postedBy == user.id
                            ? () => _delete(state, listing.id)
                            : null,
                        onChat: listing.postedBy == user.id
                            ? null
                            : () => _openEssentialThread(context, listing, listing.postedBy),
                        onBook: listing.postedBy == user.id
                            ? null
                            : () => _showBookingSheet(context, listing),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleLike(HomiesState state, EssentialListing listing, String uid) {
    state.mutate(() {
      if (listing.likes.contains(uid)) {
        listing.likes.remove(uid);
      } else {
        listing.likes.add(uid);
      }
    });
  }

  void _delete(HomiesState state, String id) {
    state.mutate(() => state.essentials.removeWhere((e) => e.id == id));
  }

  void _showPostSheet(BuildContext context, HomiesState state, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostSheet(state: state, user: user),
    );
  }

  void _showCategoryPrefsSheet(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CategoryPrefsSheet(
          categories: essentialCats.where((c) => c.$1 != 'all').toList(),
          initial: state.essentialCategoryPrefs,
          min: _catPrefsMin,
          max: _catPrefsMax,
          onSave: (selected) {
            state.mutate(() => state.essentialCategoryPrefs = selected);
            // If the currently-active filter chip just got hidden, fall back
            // to "All" instead of silently filtering by an invisible category.
            if (_filter != 'all' && !selected.contains(_filter)) {
              setState(() => _filter = 'all');
            }
          },
        ),
      ),
    );
  }

  void _showBookingSheet(BuildContext context, EssentialListing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EssentialBookingModal(listing: listing),
      ),
    );
  }

  void _openEssentialConversations(
    BuildContext context,
    List<({EssentialListing listing, String otherId, PostMessage last})> convs,
    HomiesState state,
    User cu,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Essentials messages')),
          body: convs.isEmpty
              ? const Center(
                  child: Text('No conversations yet.', style: TextStyle(color: HomiesColors.textDim)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: convs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                  itemBuilder: (_, i) {
                    final c = convs[i];
                    final other = state.findUser(c.otherId);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: HomiesColors.accentSoft,
                        child: Icon(catIcon(c.listing.category), size: 18, color: HomiesColors.accent),
                      ),
                      title: Text(other?.name ?? '—'),
                      subtitle: Text('${c.listing.businessName} · ${c.last.text}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _openEssentialThread(context, c.listing, c.otherId),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ─── Badge icon button ─────────────────────────────────────────────────────────

class _BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onPressed;
  const _BadgeIconButton({
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: HomiesColors.accent, shape: BoxShape.circle),
              child: Center(
                child: Text('$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }
}


// ─── Post sheet ───────────────────────────────────────────────────────────────

class _PostSheet extends StatefulWidget {
  final HomiesState state;
  final User user;
  const _PostSheet({required this.state, required this.user});

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _category = 'other';
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _hoursCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (name.isEmpty || desc.isEmpty) {
      setState(() => _error = 'Business name and description are required.');
      return;
    }
    widget.state.mutate(() => widget.state.essentials.add(EssentialListing(
          id: _pid(),
          postedBy: widget.user.id,
          businessName: name,
          category: _category,
          description: desc,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
          hours: _hoursCtrl.text.trim().isEmpty ? null : _hoursCtrl.text.trim(),
          address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          postedAt: DateTime.now().toIso8601String(),
        )));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: HomiesColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Post a Service',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomiesColors.text)),
            const SizedBox(height: 16),

            _formSection('The basics'),
            const FieldLabel('Business / service name'),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: "e.g. Sam's Haircut Studio"),
            ),
            const SizedBox(height: 12),

            const FieldLabel('Category'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final cat in essentialCats.where((c) => c.$1 != 'all'))
                GestureDetector(
                  onTap: () => setState(() => _category = cat.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _category == cat.$1 ? HomiesColors.accent : HomiesColors.surface2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _category == cat.$1 ? HomiesColors.accent : HomiesColors.border,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cat.$3, size: 13,
                          color: _category == cat.$1 ? Colors.white : HomiesColors.textDim),
                      const SizedBox(width: 5),
                      Text(cat.$2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _category == cat.$1 ? Colors.white : HomiesColors.text)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 12),

            const FieldLabel('Description'),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What do you offer? Mention area, hours, pricing…'),
            ),
            const SizedBox(height: 16),

            _formSection('Contact'),
            const FieldLabel('Phone (optional)'),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: '04XX XXX XXX'),
            ),
            const SizedBox(height: 12),

            const FieldLabel('Website (optional)'),
            TextField(
              controller: _websiteCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://…'),
            ),
            const SizedBox(height: 16),

            _formSection('Details'),
            const FieldLabel('Business hours (optional)'),
            TextField(
              controller: _hoursCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Mon–Fri 9am–5pm'),
            ),
            const SizedBox(height: 12),

            const FieldLabel('Address / location (optional)'),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(hintText: 'e.g. 12 Smith St, Parramatta'),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: HomiesColors.danger, fontSize: 12)),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: HomiesColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Post listing'),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Listing card ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final EssentialListing listing;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;
  final VoidCallback? onBook;
  const _ListingCard({
    required this.listing,
    required this.currentUserId,
    required this.onLike,
    this.onDelete,
    this.onChat,
    this.onBook,
  });

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _callPhone() {
    final digits = listing.phone!.replaceAll(RegExp(r'[^\d+]'), '');
    _launch('tel:$digits');
  }

  void _openWebsite() {
    final w = listing.website!;
    _launch(w.startsWith('http') ? w : 'https://$w');
  }

  @override
  Widget build(BuildContext context) {
    final liked = listing.likes.contains(currentUserId);
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: icon + name + delete
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: HomiesColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(catIcon(listing.category), size: 18, color: HomiesColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.businessName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: HomiesColors.text)),
              Text(catLabel(listing.category),
                  style: const TextStyle(fontSize: 11, color: HomiesColors.textDim)),
            ]),
          ),
          // Like button
          GestureDetector(
            onTap: onLike,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: liked ? HomiesColors.danger : HomiesColors.textFaint,
              ),
              if (listing.likes.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text('${listing.likes.length}',
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textDim)),
              ],
            ]),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: HomiesColors.textFaint),
            ),
          ],
        ]),

        const SizedBox(height: 10),
        Text(listing.description,
            style: const TextStyle(fontSize: 13, color: HomiesColors.textDim, height: 1.4)),

        // Contact row
        if (listing.phone != null || listing.website != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 6, children: [
            if (listing.phone != null)
              GestureDetector(
                onTap: _callPhone,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.phone_outlined, size: 13, color: HomiesColors.textFaint),
                  const SizedBox(width: 4),
                  Text(listing.phone!,
                      style: const TextStyle(
                          fontSize: 12, color: HomiesColors.accent, decoration: TextDecoration.underline)),
                ]),
              ),
            if (listing.website != null)
              GestureDetector(
                onTap: _openWebsite,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.language_outlined, size: 13, color: HomiesColors.textFaint),
                  const SizedBox(width: 4),
                  Text(listing.website!,
                      style: const TextStyle(
                          fontSize: 12, color: HomiesColors.accent, decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
          ]),
        ],

        // Hours / address row
        if (listing.hours != null || listing.address != null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 6, children: [
            if (listing.hours != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.schedule_outlined, size: 13, color: HomiesColors.textFaint),
                const SizedBox(width: 4),
                Text(listing.hours!, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              ]),
            if (listing.address != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_outlined, size: 13, color: HomiesColors.textFaint),
                const SizedBox(width: 4),
                Text(listing.address!, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              ]),
          ]),
        ],

        if (onChat != null || onBook != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (onChat != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: const Text('Chat', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
            if (onChat != null && onBook != null) const SizedBox(width: 8),
            if (onBook != null)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.event_outlined, size: 15),
                  label: const Text('Book appointment', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiesColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
          ]),
        ],

        const SizedBox(height: 8),
        Text(
          fmtDate(listing.postedAt),
          style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint),
        ),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String filter;
  final String query;
  final VoidCallback onPost;
  const _EmptyState({required this.filter, this.query = '', required this.onPost});

  @override
  Widget build(BuildContext context) {
    final isAll = filter == 'all';
    final hasQuery = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛍️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            hasQuery
                ? 'No listings match your search'
                : (isAll ? 'No listings yet' : 'No ${catLabel(filter).toLowerCase()} listings'),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: HomiesColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different name or clear your search.'
                : (isAll
                    ? 'Be the first to post a local service for your community.'
                    : 'Nothing in this category yet — check back soon.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: HomiesColors.textDim),
          ),
          if (isAll && !hasQuery) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onPost,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Post a service'),
            ),
          ],
        ]),
      ),
    );
  }
}
