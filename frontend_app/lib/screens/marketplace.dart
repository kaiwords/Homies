import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/media.dart';
import '../widgets/category_prefs_sheet.dart';
import '../widgets/ui_kit.dart';
import 'marketplace_thread.dart';

// ─── Category metadata ────────────────────────────────────────────────────────

const goodsCats = <(String, String, IconData)>[
  ('all',         'All',          Icons.grid_view_rounded),
  ('furniture',   'Furniture',    Icons.chair_outlined),
  ('electronics', 'Electronics',  Icons.devices_outlined),
  ('appliances',  'Appliances',   Icons.kitchen_outlined),
  ('kitchenware', 'Kitchenware',  Icons.soup_kitchen_outlined),
  ('books',       'Books & Media',Icons.menu_book_outlined),
  ('clothing',    'Clothing',     Icons.checkroom_outlined),
  ('sports',      'Sports & Outdoors', Icons.sports_basketball_outlined),
  ('other',       'Other',        Icons.category_outlined),
];

String goodsCatLabel(String key) =>
    goodsCats.firstWhere((c) => c.$1 == key, orElse: () => ('other', 'Other', Icons.category_outlined)).$2;

IconData goodsCatIcon(String key) =>
    goodsCats.firstWhere((c) => c.$1 == key, orElse: () => ('other', 'Other', Icons.category_outlined)).$3;

const _catPrefsMin = 3;
const _catPrefsMax = 10;

/// The category chips actually shown to this user: everything, until they've
/// picked a preference — then just "All" plus their chosen categories.
List<(String, String, IconData)> _visibleGoodsCats(HomiesState state) {
  if (state.goodsCategoryPrefs.isEmpty) return goodsCats;
  return [
    goodsCats.first, // 'all'
    ...goodsCats.where((c) => state.goodsCategoryPrefs.contains(c.$1)),
  ];
}

// ─── Condition metadata ───────────────────────────────────────────────────────

const goodsConditions = <(String, String)>[
  ('new',      'New'),
  ('like_new', 'Like new'),
  ('good',     'Good'),
  ('fair',     'Fair'),
  ('used',     'Used'),
];

String goodsConditionLabel(String key) =>
    goodsConditions.firstWhere((c) => c.$1 == key, orElse: () => ('good', 'Good')).$2;

const _maxPhotos = 3;

String _gid() => 'gd-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

String _fmtPrice(double price) => '\$${price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';

/// Single pass over postMessages to find this user's goods-marketplace
/// conversations, mirroring _essentialConversations' fixed algorithm.
List<({GoodsListing listing, String otherId, PostMessage last})> _goodsConversations(HomiesState state, User cu) {
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
  final listingsById = {for (final g in state.goodsListings) g.id: g};
  final out = <({GoodsListing listing, String otherId, PostMessage last})>[];
  latest.forEach((listingId, byOther) {
    final listing = listingsById[listingId];
    if (listing == null) return; // not a goods listing, or deleted
    byOther.forEach((otherId, last) => out.add((listing: listing, otherId: otherId, last: last)));
  });
  out.sort((a, b) => b.last.at.compareTo(a.last.at));
  return out;
}

void _openGoodsThread(BuildContext context, GoodsListing listing, String otherUserId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => MarketplaceThreadScreen(listing: listing, otherUserId: otherUserId)),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class GoodsMarketplaceScreen extends StatefulWidget {
  const GoodsMarketplaceScreen({super.key});

  @override
  State<GoodsMarketplaceScreen> createState() => _GoodsMarketplaceScreenState();
}

class _GoodsMarketplaceScreenState extends State<GoodsMarketplaceScreen> {
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
    final all = state.goodsListings;
    final query = _searchCtrl.text.trim().toLowerCase();
    final shown = all.where((g) {
      if (g.status != 'available' && g.postedBy != user.id) return false;
      if (_filter != 'all' && g.category != _filter) return false;
      if (query.isNotEmpty &&
          !g.title.toLowerCase().contains(query) &&
          !g.description.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    final convs = _goodsConversations(state, user);

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
                      'Marketplace',
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
                      'Buy and sell with your community.',
                      style: TextStyle(fontSize: 13, color: HomiesColors.textDim),
                    ),
                  ]),
                ),
                const SizedBox(width: 4),
                _BadgeIconButton(
                  icon: Icons.chat_bubble_outline,
                  tooltip: 'Messages',
                  count: convs.length,
                  onPressed: () => _openGoodsConversations(context, convs, state, user),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _showPostSheet(context, state, user),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Sell', style: TextStyle(fontSize: 13)),
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
                hintText: 'Search items…',
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
                for (final cat in _visibleGoodsCats(state))
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
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final listing = shown[shown.length - 1 - i]; // newest first
                      final mine = listing.postedBy == user.id;
                      return _GoodsCard(
                        listing: listing,
                        mine: mine,
                        onDelete: mine ? () => _delete(state, listing.id) : null,
                        onToggleSold: mine ? () => _toggleSold(state, listing) : null,
                        onChat: mine ? null : () => _openGoodsThread(context, listing, listing.postedBy),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _delete(HomiesState state, String id) {
    state.mutate(() => state.goodsListings.removeWhere((g) => g.id == id));
  }

  void _toggleSold(HomiesState state, GoodsListing listing) {
    state.mutate(() => listing.status = listing.status == 'sold' ? 'available' : 'sold');
  }

  void _showPostSheet(BuildContext context, HomiesState state, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostGoodsSheet(state: state, user: user),
    );
  }

  void _showCategoryPrefsSheet(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CategoryPrefsSheet(
          categories: goodsCats.where((c) => c.$1 != 'all').toList(),
          initial: state.goodsCategoryPrefs,
          min: _catPrefsMin,
          max: _catPrefsMax,
          onSave: (selected) {
            state.mutate(() => state.goodsCategoryPrefs = selected);
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

  void _openGoodsConversations(
    BuildContext context,
    List<({GoodsListing listing, String otherId, PostMessage last})> convs,
    HomiesState state,
    User cu,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Marketplace messages')),
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
                        child: Icon(goodsCatIcon(c.listing.category), size: 18, color: HomiesColors.accent),
                      ),
                      title: Text(other?.name ?? '—'),
                      subtitle: Text('${c.listing.title} · ${c.last.text}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _openGoodsThread(context, c.listing, c.otherId),
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

class _PostGoodsSheet extends StatefulWidget {
  final HomiesState state;
  final User user;
  const _PostGoodsSheet({required this.state, required this.user});

  @override
  State<_PostGoodsSheet> createState() => _PostGoodsSheetState();
}

class _PostGoodsSheetState extends State<_PostGoodsSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  String _category = 'other';
  String _condition = 'good';
  final List<Attachment> _photos = [];
  String? _error;
  bool _picking = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos || _picking) return;
    setState(() => _picking = true);
    final result = await pickImageAttachment(fromCamera: false);
    if (!mounted) return;
    setState(() => _picking = false);
    if (result.error != null) {
      setState(() => _error = result.error);
      return;
    }
    if (result.attachment != null) {
      setState(() => _photos.add(result.attachment!));
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (title.isEmpty || desc.isEmpty) {
      setState(() => _error = 'Title and description are required.');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = 'Enter a valid price.');
      return;
    }
    final location = _locationCtrl.text.trim();
    widget.state.mutate(() => widget.state.goodsListings.add(GoodsListing(
          id: _gid(),
          postedBy: widget.user.id,
          title: title,
          description: desc,
          price: price,
          category: _category,
          condition: _condition,
          location: location.isEmpty ? null : location,
          photos: List.of(_photos),
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
            const Text('Sell an item',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomiesColors.text)),
            const SizedBox(height: 16),

            const FieldLabel('Title'),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'e.g. IKEA desk, barely used'),
            ),
            const SizedBox(height: 12),

            const FieldLabel('Category'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final cat in goodsCats.where((c) => c.$1 != 'all'))
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

            const FieldLabel('Condition'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in goodsConditions)
                GestureDetector(
                  onTap: () => setState(() => _condition = c.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _condition == c.$1 ? HomiesColors.accent : HomiesColors.surface2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _condition == c.$1 ? HomiesColors.accent : HomiesColors.border,
                      ),
                    ),
                    child: Text(c.$2,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _condition == c.$1 ? Colors.white : HomiesColors.text)),
                  ),
                ),
            ]),
            const SizedBox(height: 12),

            const FieldLabel('Description'),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Size, pickup details…'),
            ),
            const SizedBox(height: 12),

            const FieldLabel('Price'),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
            ),
            const SizedBox(height: 12),

            const FieldLabel('Location (optional)'),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Parramatta, pickup only'),
            ),
            const SizedBox(height: 16),

            FieldLabel('Photos (up to $_maxPhotos)'),
            const SizedBox(height: 6),
            Row(children: [
              for (final p in _photos)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PhotoThumb(
                    attachment: p,
                    onRemove: () => setState(() => _photos.remove(p)),
                  ),
                ),
              if (_photos.length < _maxPhotos)
                GestureDetector(
                  onTap: _addPhoto,
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: HomiesColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: HomiesColors.border),
                    ),
                    child: _picking
                        ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Icon(Icons.add_a_photo_outlined, size: 20, color: HomiesColors.textDim),
                  ),
                ),
            ]),

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

class _PhotoThumb extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final bytes = decodeAttachment(attachment);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: bytes != null
              ? Image.memory(bytes, width: 64, height: 64, fit: BoxFit.cover)
              : Container(
                  width: 64, height: 64,
                  color: HomiesColors.surface2,
                  child: const Icon(Icons.broken_image_outlined, color: HomiesColors.textFaint),
                ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: HomiesColors.danger, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Listing card ─────────────────────────────────────────────────────────────

class _GoodsCard extends StatelessWidget {
  final GoodsListing listing;
  final bool mine;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleSold;
  final VoidCallback? onChat;
  const _GoodsCard({
    required this.listing,
    required this.mine,
    this.onDelete,
    this.onToggleSold,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final photo = listing.photos.isEmpty ? null : listing.photos.first;
    final bytes = photo == null ? null : decodeAttachment(photo);
    final sold = listing.status == 'sold';

    return HomiesCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Container(
                      color: HomiesColors.surface2,
                      child: Icon(goodsCatIcon(listing.category), size: 32, color: HomiesColors.textFaint),
                    ),
            ),
          ),
          if (sold)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: HomiesColors.danger, borderRadius: BorderRadius.circular(6)),
                child: const Text('SOLD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          if (mine && onDelete != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.white),
                ),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(listing.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: HomiesColors.text)),
            const SizedBox(height: 3),
            Row(children: [
              Text(_fmtPrice(listing.price),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: HomiesColors.accent)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(goodsCatLabel(listing.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textDim)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              listing.location == null
                  ? goodsConditionLabel(listing.condition)
                  : '${goodsConditionLabel(listing.condition)} · ${listing.location}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint),
            ),
            const SizedBox(height: 8),
            if (onChat != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text('Chat', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              )
            else if (onToggleSold != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onToggleSold,
                  icon: Icon(sold ? Icons.undo : Icons.sell_outlined, size: 14),
                  label: Text(sold ? 'Mark available' : 'Mark as sold', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ]),
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
          const Text('🛒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            hasQuery
                ? 'No items match your search'
                : (isAll ? 'No items for sale yet' : 'No ${goodsCatLabel(filter).toLowerCase()} listed'),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: HomiesColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different name or clear your search.'
                : (isAll
                    ? 'Be the first to sell something to your community.'
                    : 'Nothing in this category yet — check back soon.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: HomiesColors.textDim),
          ),
          if (isAll && !hasQuery) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onPost,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Sell an item'),
            ),
          ],
        ]),
      ),
    );
  }
}
