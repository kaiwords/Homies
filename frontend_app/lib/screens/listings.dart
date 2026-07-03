import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/lifestyle_fields.dart';
import '../widgets/ui_kit.dart';
import 'post_thread.dart';

const _shareable = <(String, String)>[
  ('name', 'Name'),
  ('email', 'Email'),
  ('phone', 'Phone'),
  ('moveInDate', 'Move-in date'),
];

String? _userField(User u, String key) {
  switch (key) {
    case 'name':
      return u.name;
    case 'email':
      return u.email;
    case 'phone':
      return u.phone;
    case 'moveInDate':
      return u.moveInDate;
  }
  return null;
}

bool _has(User u, String key) {
  final v = _userField(u, key);
  return v != null && v.isNotEmpty;
}

String _rid(String prefix) => '$prefix-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

bool _isOlderThanOneMonth(String createdAt) {
  final created = DateTime.tryParse(createdAt);
  if (created == null) return false;
  return DateTime.now().difference(created).inDays > 30;
}

Set<String> _participantsFor(HomiesState s, Listing l) {
  final others = <String>{};
  for (final m in s.postMessages.where((m) => m.listingId == l.id)) {
    for (final id in [m.from, m.to]) {
      if (id != l.by) others.add(id);
    }
  }
  return others;
}

void _openThread(BuildContext context, Listing listing, String otherUserId, {String? initiatorId}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PostThreadScreen(listing: listing, otherUserId: otherUserId, initiatorId: initiatorId)),
  );
}

String _prefLabel(String? val, Map<String, String> map) => val == null ? '' : (map[val] ?? val);

const _alcoholLabels = {'yes': 'Alcohol OK', 'no': 'No alcohol', 'social': 'Social only'};
const _smokingLabels = {'yes': 'Smoking OK', 'no': 'No smoking', 'outside': 'Outside only'};
const _genderLabels = {
  'any': 'Any gender',
  'female': 'Female preferred',
  'male': 'Male preferred',
  'non-binary': 'Non-binary preferred',
};

// ─── Screen ──────────────────────────────────────────────────────────────────

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String tab = 'tenant-wanted';
  bool _showArchive = false;
  final _locationCtrl = TextEditingController();

  // Filter values — null means "no filter applied"
  String? _genderFilter;
  String? _smokingFilter;
  String? _alcoholFilter;
  bool? _billsFilter; // true = bills included only

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount => [
        _genderFilter,
        _smokingFilter,
        _alcoholFilter,
        if (_billsFilter == true) 'bills',
      ].whereType<String>().length;

  void _openFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        genderFilter: _genderFilter,
        smokingFilter: _smokingFilter,
        alcoholFilter: _alcoholFilter,
        billsFilter: _billsFilter,
        onApply: (g, s, a, b) => setState(() {
          _genderFilter = g;
          _smokingFilter = s;
          _alcoholFilter = a;
          _billsFilter = b;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';

    final locationQ = _locationCtrl.text.trim().toLowerCase();
    final listings = state.listings.where((l) {
      if (l.type != tab || l.status != 'open') return false;
      if (_isOlderThanOneMonth(l.createdAt)) return false;
      if (locationQ.isNotEmpty && !l.suburb.toLowerCase().contains(locationQ)) return false;
      if (_genderFilter != null && _genderFilter != 'any' && l.genderPref != null && l.genderPref != 'any' && l.genderPref != _genderFilter) return false;
      if (_smokingFilter != null && l.smokingPref != null && l.smokingPref != _smokingFilter) return false;
      if (_alcoholFilter != null && l.alcoholPref != null && l.alcoholPref != _alcoholFilter) return false;
      if (_billsFilter == true && !l.billsIncluded) return false;
      return true;
    }).toList();

    final archivedListings = state.listings.where((l) {
      if (l.type != tab) return false;
      if (!_isOlderThanOneMonth(l.createdAt)) return false;
      return l.by == cu.id ||
          state.listingInterests.any((i) => i.listingId == l.id && (i.from == cu.id || i.to == cu.id)) ||
          state.postMessages.any((m) => m.listingId == l.id && (m.from == cu.id || m.to == cu.id)) ||
          state.inspections.any((i) => i.listingId == l.id && (i.requestedBy == cu.id || i.to == cu.id));
    }).toList();

    final inbox = state.listingInterests.where((i) => i.to == cu.id).toList();
    final sent = state.listingInterests.where((i) => i.from == cu.id).toList();
    final inspectionInbox = state.inspections.where((i) => i.to == cu.id).toList();
    final myInspections = state.inspections.where((i) => i.requestedBy == cu.id).toList();
    final convs = _myConversations(state, cu);
    final fc = _activeFilterCount;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Rooms & housemates',
            subtitle: isLeaseholder
                ? 'Advertise a free room or post that you\'re looking. Message people directly.'
                : 'Browse available rooms or let others know you\'re looking.',
            action: tab == 'tenant-wanted' && isLeaseholder
                ? ElevatedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: const _ListingModal(type: 'tenant-wanted'),
                      ),
                    ),
                    child: const Text('+ List a room'),
                  )
                : tab == 'room-wanted'
                    ? ElevatedButton(
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => Padding(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                            child: const _ListingModal(type: 'room-wanted'),
                          ),
                        ),
                        child: const Text('+ I\'m looking'),
                      )
                    : null,
          ),

          // Tab switcher + chat icon
          Row(children: [
            Segment<String>(
              options: const ['tenant-wanted', 'room-wanted'],
              value: tab,
              labelFor: (t) => t == 'tenant-wanted' ? 'Rooms available' : 'People looking',
              onChanged: (t) => setState(() => tab = t),
              optionPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Messages',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => _openConversationsPage(context, convs, state, cu),
                ),
                if (convs.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: HomiesColors.accent, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${convs.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 12),

          // Search + filter row
          Row(children: [
            Expanded(
              child: TextField(
                controller: _locationCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search by suburb…',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openFilters(context),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Filters'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (fc > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(color: HomiesColors.accent, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$fc', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 12),

          if (listings.isEmpty)
            EmptyState(
              title: 'Nothing here yet',
              body: tab == 'tenant-wanted' ? 'No rooms listed right now.' : 'No one is looking right now.',
            ),
          for (final l in listings)
            _PostCard(
              listing: l,
              mine: l.by == cu.id,
              alreadySent: sent.any((i) => i.listingId == l.id),
            ),

          // Incoming leaseholder-to-leaseholder performance requests
          ..._incomingPerfRequests(state, cu),

          if (inbox.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Interest in your listings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            for (final i in inbox) _InterestCard(interest: i),
          ],
          if (inspectionInbox.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Inspection requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            for (final i in inspectionInbox) _InspectionCard(inspection: i, incoming: true),
          ],
          if (myInspections.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Your inspections', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            for (final i in myInspections) _InspectionCard(inspection: i, incoming: false),
          ],

          // Leaseholder complaint section — tenants only
          if (cu.member && !isLeaseholder) ...[
            const SizedBox(height: 8),
            _LeaseholderReportBanner(cu: cu),
          ],

          // Archive: posts older than 30 days the current user interacted with
          if (archivedListings.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1, color: HomiesColors.border),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showArchive = !_showArchive),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.archive_outlined, size: 18, color: HomiesColors.textDim),
                  const SizedBox(width: 8),
                  Text(
                    'Archive · ${archivedListings.length} post${archivedListings.length == 1 ? '' : 's'} over 30 days old',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.textDim),
                  ),
                  const Spacer(),
                  Icon(_showArchive ? Icons.expand_less : Icons.expand_more, color: HomiesColors.textDim, size: 18),
                ]),
              ),
            ),
            if (_showArchive)
              ...archivedListings.map((l) => Opacity(
                    opacity: 0.65,
                    child: _PostCard(
                      listing: l,
                      mine: l.by == cu.id,
                      alreadySent: sent.any((i) => i.listingId == l.id),
                    ),
                  )),
          ],
        ]),
      ),
    );
  }

  List<({Listing listing, String otherId, String initiatorId, PostMessage last})> _myConversations(HomiesState state, User cu) {
    // Single pass over postMessages (O(M)) instead of nested-looping listings
    // x partners x postMessages with a re-filter per partner — that used to
    // recompute from scratch on every rebuild, including remote sync events
    // now that listings/postMessages sync live via Firestore, which showed
    // up as UI lag on this screen.
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
    final listingsById = {for (final l in state.listings) l.id: l};
    final out = <({Listing listing, String otherId, String initiatorId, PostMessage last})>[];
    latest.forEach((listingId, byOther) {
      final listing = listingsById[listingId];
      if (listing == null) return; // not a room listing (e.g. an essentials business), or deleted
      byOther.forEach((otherId, last) =>
          out.add((listing: listing, otherId: otherId, initiatorId: cu.id, last: last)));
    });
    out.sort((a, b) => b.last.at.compareTo(a.last.at));
    return out;
  }

  void _openConversationsPage(
    BuildContext context,
    List<({Listing listing, String otherId, String initiatorId, PostMessage last})> convs,
    HomiesState state,
    User cu,
  ) {
    final leaseholderConvs = convs.where((c) => state.findUser(c.otherId)?.role == 'leaseholder').toList();
    final otherConvs = convs.where((c) => state.findUser(c.otherId)?.role != 'leaseholder').toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Messages')),
          body: convs.isEmpty
              ? const Center(
                  child: Text('No conversations yet.',
                      style: TextStyle(color: HomiesColors.textDim)),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (leaseholderConvs.isNotEmpty) ...[
                      _convSectionLabel('Leaseholders'),
                      for (final c in leaseholderConvs) ...[
                        _convTile(context, state, cu, c),
                        const Divider(height: 1, indent: 68),
                      ],
                    ],
                    if (otherConvs.isNotEmpty) ...[
                      if (leaseholderConvs.isNotEmpty) const SizedBox(height: 4),
                      _convSectionLabel('Tenants & applicants'),
                      for (final c in otherConvs) ...[
                        _convTile(context, state, cu, c),
                        const Divider(height: 1, indent: 68),
                      ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // Returns banner cards for every unanswered perf-request addressed to cu.
  List<Widget> _incomingPerfRequests(HomiesState state, User cu) {
    final out = <Widget>[];
    for (final l in state.listings) {
      final requests = state.postMessages
          .where((m) => m.listingId == l.id && m.to == cu.id && m.kind == 'perf-request')
          .toList();
      for (final req in requests) {
        final thread = threadMessages(state, l.id, req.from, cu.id);
        final answered = thread.any((m) => m.kind == 'perf-share' && m.from == cu.id && m.at.compareTo(req.at) > 0);
        if (answered) continue;
        final requester = state.findUser(req.from);
        out.add(_PerfRequestBanner(
          requester: requester,
          listing: l,
          onOpen: () => _openThread(context, l, cu.id, initiatorId: req.from),
        ));
      }
    }
    if (out.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      const Text('Performance requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ...out,
    ];
  }

  Widget _convSectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.8)),
      );

  Widget _convTile(
    BuildContext context,
    HomiesState state,
    User cu,
    ({Listing listing, String otherId, String initiatorId, PostMessage last}) c,
  ) {
    final other = state.findUser(c.otherId);
    final preview = switch (c.last.kind) {
      'perf-share' => '📋 Shared a performance reference',
      'inspection-invite' => '📅 Inspection invited',
      'inspection-confirm' => '✅ Inspection confirmed',
      'perf-request' => '🔖 Performance reference requested',
      _ => c.last.text,
    };
    final isL2L = c.initiatorId != c.listing.by;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openThread(
        context, c.listing, c.otherId,
        initiatorId: isL2L ? c.initiatorId : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Avatar(user: other),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(other?.name ?? '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(fmtDateShort(c.last.at),
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
              ]),
              Text(c.listing.title,
                  style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(preview,
                  style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const Icon(Icons.chevron_right, size: 18, color: HomiesColors.textFaint),
        ]),
      ),
    );
  }
}

// ─── Filter sheet ─────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String? genderFilter;
  final String? smokingFilter;
  final String? alcoholFilter;
  final bool? billsFilter;
  final void Function(String? gender, String? smoking, String? alcohol, bool? bills) onApply;

  const _FilterSheet({
    required this.genderFilter,
    required this.smokingFilter,
    required this.alcoholFilter,
    required this.billsFilter,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _gender;
  String? _smoking;
  String? _alcohol;
  bool? _bills;

  @override
  void initState() {
    super.initState();
    _gender = widget.genderFilter;
    _smoking = widget.smokingFilter;
    _alcohol = widget.alcoholFilter;
    _bills = widget.billsFilter;
  }

  void _reset() => setState(() {
        _gender = null;
        _smoking = null;
        _alcohol = null;
        _bills = null;
      });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: _reset, child: const Text('Reset all')),
          ]),
          const SizedBox(height: 16),

          const FieldLabel('Gender preference'),
          const SizedBox(height: 6),
          _PrefRow(
            options: _genderLabels,
            value: _gender,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 14),

          const FieldLabel('Smoking'),
          const SizedBox(height: 6),
          _PrefRow(
            options: _smokingLabels,
            value: _smoking,
            onChanged: (v) => setState(() => _smoking = v),
          ),
          const SizedBox(height: 14),

          const FieldLabel('Alcohol'),
          const SizedBox(height: 6),
          _PrefRow(
            options: _alcoholLabels,
            value: _alcohol,
            onChanged: (v) => setState(() => _alcohol = v),
          ),
          const SizedBox(height: 14),

          const FieldLabel('Bills'),
          const SizedBox(height: 6),
          _PrefRow(
            options: const {'true': 'Bills included'},
            value: _bills == true ? 'true' : null,
            onChanged: (v) => setState(() => _bills = v == 'true' ? true : null),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              widget.onApply(_gender, _smoking, _alcohol, _bills);
              Navigator.pop(context);
            },
            child: const Text('Apply filters'),
          ),
        ]),
      ),
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final Listing listing;
  final bool mine;
  final bool alreadySent;
  const _PostCard({required this.listing, required this.mine, required this.alreadySent});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final by = state.findUser(listing.by);
    final isRoom = listing.type == 'tenant-wanted';
    final participants = _participantsFor(state, listing);
    final interestCount = state.listingInterests.where((i) => i.listingId == listing.id).length;

    final prefChips = <String>[
      if (listing.billsIncluded) 'Bills incl.',
      if (listing.hasPool) 'Pool',
      if (listing.hasParking) 'Parking',
      if (listing.alcoholPref != null) _prefLabel(listing.alcoholPref, _alcoholLabels),
      if (listing.smokingPref != null) _prefLabel(listing.smokingPref, _smokingLabels),
      if (listing.genderPref != null && listing.genderPref != 'any')
        _prefLabel(listing.genderPref, _genderLabels),
    ].where((s) => s.isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: isRoom ? HomiesColors.accent : const Color(0xFF356190),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Avatar(user: by),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(by?.name ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    HomiesChip(
                      by?.role == 'leaseholder' ? 'Leaseholder' : 'Tenant',
                      tone: by?.role == 'leaseholder' ? ChipTone.accent : ChipTone.info,
                    ),
                  ]),
                  Text('${listing.suburb} · ${fmtRelative(listing.createdAt)}',
                      style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                ]),
              ),
              if (mine && interestCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HomiesColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.how_to_reg_outlined, size: 13, color: HomiesColors.accent),
                      const SizedBox(width: 4),
                      Text('$interestCount ${interestCount == 1 ? 'request' : 'requests'}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: HomiesColors.accentStrong)),
                    ]),
                  ),
                ),
              _PostCardMenu(listing: listing, mine: mine),
            ]),
            const SizedBox(height: 12),
            Text(listing.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (isRoom && listing.rent != null)
                HomiesChip('${fmtAUD(listing.rent)}/wk', tone: ChipTone.accent),
              if (!isRoom && listing.budget != null)
                HomiesChip('Budget ${fmtAUD(listing.budget)}/wk', tone: ChipTone.accent),
              if (listing.availableFrom != null && listing.availableFrom!.isNotEmpty)
                HomiesChip('From ${fmtDate(listing.availableFrom)}'),
              for (final c in prefChips) HomiesChip(c),
            ]),
            if (listing.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(listing.description,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: HomiesColors.text)),
              ),
            if (!mine && by?.role == 'leaseholder') ...[
              const SizedBox(height: 12),
              _LhReputationSection(leaseholderId: listing.by),
            ],
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: HomiesColors.border)),
            if (mine)
              _ownerFooter(context, state, participants)
            else
              _visitorFooter(context, cu),
          ]),
        ),
      ]),
    );
  }

  Widget _ownerFooter(BuildContext context, HomiesState state, Set<String> participants) {
    if (participants.isEmpty) {
      return const Row(children: [
        Icon(Icons.forum_outlined, size: 16, color: HomiesColors.textFaint),
        SizedBox(width: 6),
        Text('Your listing · no messages yet',
            style: TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
      ]);
    }
    final people = participants.map((id) => state.findUser(id)).whereType<User>().toList();
    return Row(children: [
      AvatarStack(users: people),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
            '${participants.length} ${participants.length == 1 ? 'person' : 'people'} messaged you',
            style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
      ),
      ElevatedButton(
        onPressed: () => _openConversationPicker(context, people),
        child: const Text('View chats'),
      ),
    ]);
  }

  void _openConversationPicker(BuildContext context, List<User> people) {
    if (people.length == 1) {
      _openThread(context, listing, people.first.id);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Conversations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),
          for (final p in people)
            ListTile(
              leading: Avatar(user: p),
              title: Text(p.name),
              subtitle: Text(p.role),
              onTap: () {
                Navigator.pop(context);
                _openThread(context, listing, p.id);
              },
            ),
        ]),
      ),
    );
  }

  Widget _visitorFooter(BuildContext context, User cu) {
    final state = HomiesScope.of(context);
    final isLooking = listing.type == 'room-wanted';
    final hasThread =
        state.postMessages.any((m) => m.listingId == listing.id && (m.from == cu.id || m.to == cu.id));
    final sentInspection = state.inspections.any(
        (i) => i.listingId == listing.id && i.requestedBy == cu.id && i.status != 'declined');

    // L2L: leaseholder viewing a tenant's listing that has a leaseholder reference
    final by = state.findUser(listing.by);
    final lhRefId = cu.role == 'leaseholder' && by?.role == 'tenant' ? by?.leaseholderUserId : null;
    final lhRef = lhRefId != null ? state.findUser(lhRefId) : null;
    final alreadyRequested = lhRefId != null &&
        state.postMessages.any((m) =>
            m.listingId == listing.id && m.from == cu.id && m.to == lhRefId && m.kind == 'perf-request');

    return Column(children: [
      if (lhRef != null) ...[
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: alreadyRequested
                ? null
                : () {
                    final msg = PostMessage(
                      id: _rid('pm'),
                      listingId: listing.id,
                      from: cu.id,
                      to: lhRefId!,
                      text: '${cu.name.split(' ').first} asked about one of your tenants\' track record.',
                      at: DateTime.now().toIso8601String(),
                      kind: 'perf-request',
                    );
                    state.mutate(() => state.postMessages.add(msg));
                    _openThread(context, listing, lhRefId, initiatorId: cu.id);
                  },
            icon: const Icon(Icons.workspace_premium_outlined, size: 16),
            label: Text(alreadyRequested
                ? 'Request sent to ${lhRef.name.split(' ').first}'
                : 'Request performance from ${lhRef.name.split(' ').first}'),
          ),
        ),
        const SizedBox(height: 8),
      ],
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: alreadySent
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding:
                            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: _ShareInfoModal(listing: listing),
                      ),
                    ),
            child: Text(alreadySent ? 'Interest sent' : 'Share details'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openThread(context, listing, cu.id),
            icon: Icon(hasThread ? Icons.forum : Icons.chat_bubble_outline, size: 16),
            label: Text(hasThread ? 'Open chat' : 'Message'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: sentInspection
              ? null
              : () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => Padding(
                      padding:
                          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: _InspectionModal(listing: listing, isInvite: isLooking),
                    ),
                  ),
          icon: Icon(isLooking ? Icons.person_add_outlined : Icons.event_available_outlined, size: 16),
          label: Text(sentInspection
              ? (isLooking ? 'Invite sent' : 'Inspection requested')
              : (isLooking ? 'Invite for inspection' : 'Book an inspection')),
        ),
      ),
    ]);
  }
}

// ─── Post card menu (share / report) ─────────────────────────────────────────

class _PostCardMenu extends StatelessWidget {
  final Listing listing;
  final bool mine;
  const _PostCardMenu({required this.listing, required this.mine});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: HomiesColors.textFaint),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share_outlined),
            title: Text('Share post'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (!mine)
          const PopupMenuItem(
            value: 'report',
            child: ListTile(
              leading: Icon(Icons.flag_outlined, color: HomiesColors.danger),
              title: Text('Report post', style: TextStyle(color: HomiesColors.danger)),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
      onSelected: (v) {
        if (v == 'share') _share(context);
        if (v == 'report') _report(context);
      },
    );
  }

  void _share(BuildContext context) {
    final isRoom = listing.type == 'tenant-wanted';
    final priceText = isRoom && listing.rent != null
        ? '\$${listing.rent!.toStringAsFixed(0)}/wk'
        : (!isRoom && listing.budget != null)
            ? 'Budget \$${listing.budget!.toStringAsFixed(0)}/wk'
            : '';
    final parts = [
      listing.title,
      '${listing.suburb}${priceText.isNotEmpty ? ' · $priceText' : ''}',
      if (listing.description.isNotEmpty) listing.description,
    ];
    Clipboard.setData(ClipboardData(text: parts.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post details copied to clipboard')),
    );
  }

  void _report(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ReportPostModal(listing: listing),
      ),
    );
  }
}

// ─── Report post modal ────────────────────────────────────────────────────────

class _ReportPostModal extends StatefulWidget {
  final Listing listing;
  const _ReportPostModal({required this.listing});

  @override
  State<_ReportPostModal> createState() => _ReportPostModalState();
}

class _ReportPostModalState extends State<_ReportPostModal> {
  String? _category;
  final _reasonCtrl = TextEditingController();

  static const _categories = <(String, String)>[
    ('spam', 'Spam or misleading'),
    ('fake', 'Fake or scam listing'),
    ('inappropriate', 'Inappropriate content'),
    ('duplicate', 'Duplicate post'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _category != null;

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: HomiesColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.flag_outlined, size: 22, color: HomiesColors.danger),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Report this post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('"${widget.listing.title}"',
                    style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          const FieldLabel('Reason for reporting'),
          DropdownButtonFormField<String>(
            hint: const Text('Select a reason'),
            initialValue: _category,
            items: [
              for (final c in _categories)
                DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          const FieldLabel('Details (optional)'),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Anything specific to help us review this post…'),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _canSubmit
                  ? () {
                      final catLabel = _categories.firstWhere((c) => c.$1 == _category).$2;
                      final detail = _reasonCtrl.text.trim();
                      state.mutate(() => state.complaints.insert(
                            0,
                            Complaint(
                              id: 'rpt-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
                              against: widget.listing.by,
                              from: cu.id,
                              reason: detail.isNotEmpty ? '$catLabel: $detail' : catLabel,
                              severity: 1,
                              date: DateTime.now().toIso8601String().substring(0, 10),
                              kind: 'listing',
                              category: _category,
                            ),
                          ));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report submitted. Thanks for keeping Homies safe.')),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomiesColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit report'),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Interest card ────────────────────────────────────────────────────────────

({IconData icon, Color color}) _interestStatusVisual(String status) => switch (status) {
      'accepted' => (icon: Icons.check_circle_outline, color: HomiesColors.ok),
      'declined' => (icon: Icons.cancel_outlined, color: HomiesColors.danger),
      _ => (icon: Icons.schedule_outlined, color: HomiesColors.warn),
    };

class _InterestCard extends StatelessWidget {
  final ListingInterest interest;
  const _InterestCard({required this.interest});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final from = state.findUser(interest.from);
    final listing = state.listings.firstWhereOrNull((l) => l.id == interest.listingId);
    final statusTone = interest.status == 'accepted'
        ? ChipTone.ok
        : interest.status == 'declined'
            ? ChipTone.danger
            : ChipTone.warn;
    final statusVisual = _interestStatusVisual(interest.status);

    return HomiesCard(
      color: HomiesColors.surface2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Re: ${listing?.title ?? 'listing'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusVisual.icon, size: 13, color: statusVisual.color),
                    const SizedBox(width: 4),
                    HomiesChip(interest.status, tone: statusTone),
                  ])),
            ]),
          ),
          Avatar.sm(from),
        ]),
        if (interest.message.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('"${interest.message}"', style: const TextStyle(fontSize: 13))),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: HomiesColors.surface,
            border: Border.all(color: HomiesColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('SHARED DETAILS',
                style: TextStyle(
                    fontSize: 11,
                    color: HomiesColors.textDim,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final f in _shareable)
              if ((interest.sharedFields[f.$1] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(f.$2, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                    Text(
                      f.$1 == 'moveInDate'
                          ? fmtDate(interest.sharedFields[f.$1])
                          : interest.sharedFields[f.$1]!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
          ]),
        ),
        if (interest.lifestyle != null || (interest.emergency?.isComplete ?? false))
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: HomiesColors.surface,
              border: Border.all(color: HomiesColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('LIFESTYLE & EMERGENCY',
                  style: TextStyle(
                      fontSize: 11,
                      color: HomiesColors.textDim,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              LifestyleSummary(lifestyle: interest.lifestyle, emergency: interest.emergency),
            ]),
          ),
        if (interest.status == 'pending')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => state.mutate(() => interest.status = 'declined'),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final email = interest.sharedFields['email'] ?? from?.email ?? '';
                  final invite = await state.createInvite(email: email, role: 'tenant');
                  state.mutate(() {
                    interest.status = 'accepted';
                    interest.inviteCode = invite.code;
                  });
                  state.addAppNotification(AppNotification(
                    id: 'li_${interest.id}_accepted',
                    kind: 'listing_interest',
                    title: 'Your application was accepted!',
                    body: listing != null
                        ? "You've been invited to join ${listing.title} — open the app to finish joining."
                        : "You've been invited to join the house — open the app to finish joining.",
                    at: DateTime.now().toIso8601String(),
                    forUserId: interest.from,
                  ));
                },
                child: const Text('Accept & share contact'),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ─── Post modal ───────────────────────────────────────────────────────────────

class _ListingModal extends StatefulWidget {
  final String type;
  const _ListingModal({required this.type});

  @override
  State<_ListingModal> createState() => _ListingModalState();
}

class _ListingModalState extends State<_ListingModal> {
  final titleCtrl = TextEditingController();
  final suburbCtrl = TextEditingController();
  final rentCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  DateTime? availableFrom;
  bool billsIncluded = false;
  bool hasPool = false;
  bool hasParking = false;
  String? alcoholPref;
  String? smokingPref;
  String? genderPref;

  bool get _isRoom => widget.type == 'tenant-wanted';

  @override
  void dispose() {
    titleCtrl.dispose();
    suburbCtrl.dispose();
    rentCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final canSave = titleCtrl.text.trim().isNotEmpty && suburbCtrl.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isRoom ? 'List a room' : "Post what you're looking for",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                const FieldLabel('Title'),
                TextField(
                  controller: titleCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _isRoom
                        ? 'Sunny double room in 4-bed house'
                        : 'Quiet professional after a room near the city',
                  ),
                ),
                const SizedBox(height: 14),

                const FieldLabel('Suburb / location'),
                TextField(
                  controller: suburbCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Marrickville'),
                ),
                const SizedBox(height: 14),

                FieldLabel(_isRoom ? 'Rent (\$/week)' : 'Budget (\$/week)'),
                TextField(
                  controller: rentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '0'),
                ),
                const SizedBox(height: 14),

                FieldLabel(_isRoom ? 'Available from' : 'Move in by'),
                OutlinedButton(
                  onPressed: () async {
                    final d = await pickDate(context, initial: availableFrom);
                    if (d != null) setState(() => availableFrom = d);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(availableFrom == null
                        ? 'Pick a date'
                        : fmtDate(toIso(availableFrom))),
                  ),
                ),
                const SizedBox(height: 14),

                const FieldLabel('Description'),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(hintText: 'A bit about the place / yourself…'),
                ),

                if (_isRoom) ...[
                  const SizedBox(height: 14),
                  const Text('Property features',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Bills included in rent', style: TextStyle(fontSize: 14)),
                    value: billsIncluded,
                    onChanged: (v) => setState(() => billsIncluded = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Swimming pool', style: TextStyle(fontSize: 14)),
                    value: hasPool,
                    onChanged: (v) => setState(() => hasPool = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Parking / garage', style: TextStyle(fontSize: 14)),
                    value: hasParking,
                    onChanged: (v) => setState(() => hasParking = v),
                  ),
                ],

                const SizedBox(height: 14),
                const Text('Lifestyle preferences',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),

                const FieldLabel('Alcohol'),
                _PrefRow(
                  options: _alcoholLabels,
                  value: alcoholPref,
                  onChanged: (v) => setState(() => alcoholPref = v),
                ),
                const SizedBox(height: 14),

                const FieldLabel('Smoking'),
                _PrefRow(
                  options: _smokingLabels,
                  value: smokingPref,
                  onChanged: (v) => setState(() => smokingPref = v),
                ),
                const SizedBox(height: 14),

                const FieldLabel('Gender preference'),
                _PrefRow(
                  options: _genderLabels,
                  value: genderPref,
                  onChanged: (v) => setState(() => genderPref = v),
                ),
                const SizedBox(height: 20),

                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: !canSave
                        ? null
                        : () {
                            final amount = double.tryParse(rentCtrl.text.trim());
                            state.mutate(() => state.listings.insert(
                                  0,
                                  Listing(
                                    id: _rid('lst'),
                                    type: widget.type,
                                    by: state.currentUser!.id,
                                    title: titleCtrl.text.trim(),
                                    suburb: suburbCtrl.text.trim(),
                                    rent: _isRoom ? amount : null,
                                    budget: _isRoom ? null : amount,
                                    availableFrom: toIso(availableFrom),
                                    description: descCtrl.text.trim(),
                                    createdAt: todayIso(),
                                    billsIncluded: _isRoom ? billsIncluded : false,
                                    hasPool: _isRoom ? hasPool : false,
                                    hasParking: _isRoom ? hasParking : false,
                                    alcoholPref: alcoholPref,
                                    smokingPref: smokingPref,
                                    genderPref: genderPref,
                                  ),
                                ));
                            Navigator.pop(context);
                          },
                    child: const Text('Post listing'),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─── Pref chip row ────────────────────────────────────────────────────────────

class _PrefRow extends StatelessWidget {
  final Map<String, String> options;
  final String? value;
  final void Function(String?) onChanged;
  const _PrefRow({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.entries.map((e) {
        final selected = value == e.key;
        return GestureDetector(
          onTap: () => onChanged(selected ? null : e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? HomiesColors.accent : HomiesColors.surface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? HomiesColors.accent : HomiesColors.border),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : HomiesColors.text,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Share info modal ─────────────────────────────────────────────────────────

class _ShareInfoModal extends StatefulWidget {
  final Listing listing;
  const _ShareInfoModal({required this.listing});

  @override
  State<_ShareInfoModal> createState() => _ShareInfoModalState();
}

class _ShareInfoModalState extends State<_ShareInfoModal> {
  final Map<String, bool> picked = {};
  final msgCtrl = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final cu = HomiesScope.of(context).currentUser!;
    for (final f in _shareable) {
      picked[f.$1] = _has(cu, f.$1);
    }
  }

  @override
  void dispose() {
    msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final anyPicked = _shareable.any((f) => (picked[f.$1] ?? false) && _has(cu, f.$1));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Apply for this room',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const Text(
                  'Applying shares your lifestyle answers and emergency contact with the leaseholder, plus the contact details you tick below.',
                  style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Share these details'),
                for (final f in _shareable)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: picked[f.$1] ?? false,
                    onChanged:
                        _has(cu, f.$1) ? (v) => setState(() => picked[f.$1] = v ?? false) : null,
                    title: Text(
                      _has(cu, f.$1) ? f.$2 : '${f.$2} (not set)',
                      style: TextStyle(
                          fontSize: 14,
                          color: _has(cu, f.$1) ? HomiesColors.text : HomiesColors.textFaint),
                    ),
                  ),
                const SizedBox(height: 8),
                if (cu.profileComplete) ...[
                  const FieldLabel('Also shared with your application'),
                  HomiesCard(
                    color: HomiesColors.surface2,
                    child: LifestyleSummary(lifestyle: cu.lifestyle, emergency: cu.emergency),
                  ),
                ] else
                  HomiesCard(
                    color: HomiesColors.surface2,
                    borderColor: HomiesColors.warnBorder,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Complete your profile to apply',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      const Text(
                        'Applicants share their lifestyle answers and an emergency contact with the leaseholder.',
                        style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.go('/app/profile');
                          },
                          child: const Text('Go to profile'),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 6),
                const FieldLabel('Message (optional)'),
                TextField(
                    controller: msgCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        hintText: "Hi! I'm interested — a bit about me…")),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: !anyPicked || !cu.profileComplete
                        ? null
                        : () {
                            final shared = <String, String>{};
                            for (final f in _shareable) {
                              if ((picked[f.$1] ?? false) && _has(cu, f.$1)) {
                                shared[f.$1] = _userField(cu, f.$1)!;
                              }
                            }
                            state.mutate(() => state.listingInterests.insert(
                                  0,
                                  ListingInterest(
                                    id: _rid('int'),
                                    listingId: widget.listing.id,
                                    from: cu.id,
                                    to: widget.listing.by,
                                    message: msgCtrl.text.trim(),
                                    sharedFields: shared,
                                    lifestyle: cu.lifestyle,
                                    emergency: cu.emergency,
                                    createdAt: todayIso(),
                                  ),
                                ));
                            Navigator.pop(context);
                          },
                    child: const Text('Send application'),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─── Inspection modal ─────────────────────────────────────────────────────────

class _InspectionModal extends StatefulWidget {
  final Listing listing;
  final bool isInvite;
  const _InspectionModal({required this.listing, this.isInvite = false});

  @override
  State<_InspectionModal> createState() => _InspectionModalState();
}

class _InspectionModalState extends State<_InspectionModal> {
  DateTime? _date;
  final _slotCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

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
                Text(
                  widget.isInvite ? 'Invite for inspection' : 'Book an inspection',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.isInvite
                      ? 'Suggest a time for ${widget.listing.by} to come inspect your place.'
                      : 'Request a time to view ${widget.listing.title}. The leaseholder confirms or suggests another time.',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
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
                    decoration: const InputDecoration(hintText: 'e.g. 10:00 am or after 5pm')),
                const SizedBox(height: 14),
                const FieldLabel('Note (optional)'),
                TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Anything the leaseholder should know…')),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: !canBook
                        ? null
                        : () {
                            state.mutate(() => state.inspections.insert(
                                  0,
                                  Inspection(
                                    id: _rid('insp'),
                                    listingId: widget.listing.id,
                                    requestedBy: cu.id,
                                    to: widget.listing.by,
                                    date: toIso(_date)!,
                                    slot: _slotCtrl.text.trim(),
                                    note: _noteCtrl.text.trim(),
                                    createdAt: todayIso(),
                                  ),
                                ));
                            Navigator.pop(context);
                          },
                    child: Text(widget.isInvite ? 'Send invite' : 'Request inspection'),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─── Inspection card ──────────────────────────────────────────────────────────

class _InspectionCard extends StatelessWidget {
  final Inspection inspection;
  final bool incoming;
  const _InspectionCard({required this.inspection, required this.incoming});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final i = inspection;
    final other = state.findUser(incoming ? i.requestedBy : i.to);
    final listing = state.listings.firstWhereOrNull((l) => l.id == i.listingId);
    final tone = i.status == 'confirmed'
        ? ChipTone.ok
        : i.status == 'declined'
            ? ChipTone.danger
            : ChipTone.warn;

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
                    ? '${other?.name ?? '—'} wants to inspect'
                    : 'Inspection with ${other?.name ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(listing?.title ?? 'the property',
                  style: const TextStyle(color: HomiesColors.textFaint, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('${fmtDate(i.date)} · ${i.slot}',
                  style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          HomiesChip(i.status, tone: tone),
        ]),
        if (i.note.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('"${i.note}"', style: const TextStyle(fontSize: 12))),
        if (incoming && i.status == 'requested')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => state.mutate(() => i.status = 'declined'),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => state.mutate(() => i.status = 'confirmed'),
                child: const Text('Confirm'),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ─── Perf request banner ──────────────────────────────────────────────────────

class _PerfRequestBanner extends StatelessWidget {
  final User? requester;
  final Listing listing;
  final VoidCallback onOpen;
  const _PerfRequestBanner({required this.requester, required this.listing, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return HomiesCard(
      borderColor: HomiesColors.accentBorder,
      color: HomiesColors.accentBorder,
      child: Row(children: [
        const Icon(Icons.workspace_premium_rounded, size: 22, color: HomiesColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${requester?.name ?? 'A leaseholder'} asked about a tenant',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              'Re: ${listing.title}',
              style: const TextStyle(fontSize: 12, color: HomiesColors.accentStrong),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onOpen, child: const Text('Respond')),
      ]),
    );
  }
}

// ─── Leaseholder reputation (on listing cards — tenant browsing) ─────────────

class _LhReputationSection extends StatelessWidget {
  final String leaseholderId;
  const _LhReputationSection({required this.leaseholderId});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final reviews = state.lhReviews.where((r) => r.leaseholderId == leaseholderId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final complaints = state.complaints
        .where((c) => c.kind == 'leaseholder' && c.against == leaseholderId)
        .toList();
    final avgRating = reviews.isEmpty
        ? null
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final alreadyReviewed = reviews.any((r) => r.fromUserId == cu.id);
    final isTenant = cu.role != 'leaseholder';

    final cCount = complaints.length;
    final complaintTone = cCount == 0
        ? ChipTone.ok
        : cCount <= 2
            ? ChipTone.warn
            : ChipTone.danger;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield_outlined, size: 14, color: HomiesColors.textDim),
          const SizedBox(width: 5),
          const Text('Leaseholder reputation',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomiesColors.textDim)),
          const Spacer(),
          if (isTenant && !alreadyReviewed)
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: _LhReviewModal(leaseholderId: leaseholderId),
                ),
              ),
              child: const Text('+ Leave a review',
                  style: TextStyle(fontSize: 11, color: HomiesColors.accent, fontWeight: FontWeight.w600)),
            ),
          if (alreadyReviewed)
            const Text('You reviewed this leaseholder',
                style: TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
        ]),
        const SizedBox(height: 8),

        Wrap(spacing: 6, runSpacing: 4, children: [
          HomiesChip(
            cCount == 0 ? 'No complaints' : '$cCount complaint${cCount == 1 ? '' : 's'}',
            tone: complaintTone,
          ),
          if (avgRating != null)
            HomiesChip('★ ${avgRating.toStringAsFixed(1)} · ${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                tone: ChipTone.neutral),
          if (reviews.isEmpty)
            const HomiesChip('No reviews yet'),
        ]),

        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LhReviewTile(review: reviews.first),
          if (reviews.length > 1) ...[
            const SizedBox(height: 6),
            _LockedMoreReviews(count: reviews.length - 1),
          ],
        ],
      ]),
    );
  }
}

class _LhReviewTile extends StatelessWidget {
  final LeaseholderReview review;
  const _LhReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 13, color: i <= r.rating ? const Color(0xFFF6AD55) : HomiesColors.textFaint),
          ]),
          const SizedBox(width: 6),
          Text(r.anonymous ? 'Anonymous tenant' : r.fromUserName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: HomiesColors.textDim)),
          const Spacer(),
          Text(fmtDate(r.date), style: const TextStyle(fontSize: 10, color: HomiesColors.textFaint)),
        ]),
        const SizedBox(height: 4),
        Text(r.body, style: const TextStyle(fontSize: 12, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _LockedMoreReviews extends StatelessWidget {
  final int count;
  const _LockedMoreReviews({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.lock_outline, size: 15, color: HomiesColors.textFaint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$count more review${count == 1 ? '' : 's'} — unlock with Premium',
            style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HomiesColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: HomiesColors.border),
          ),
          child: const Text('Coming soon', style: TextStyle(fontSize: 10, color: HomiesColors.textFaint)),
        ),
      ]),
    );
  }
}

// ─── Leave a review modal ─────────────────────────────────────────────────────

class _LhReviewModal extends StatefulWidget {
  final String leaseholderId;
  const _LhReviewModal({required this.leaseholderId});

  @override
  State<_LhReviewModal> createState() => _LhReviewModalState();
}

class _LhReviewModalState extends State<_LhReviewModal> {
  int rating = 3;
  final bodyCtrl = TextEditingController();
  bool anonymous = false;

  @override
  void dispose() {
    bodyCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => bodyCtrl.text.trim().length >= 10;

  void _submit() {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    state.addLhReview(LeaseholderReview(
      id: 'lhr-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      leaseholderId: widget.leaseholderId,
      fromUserId: cu.id,
      fromUserName: cu.name,
      anonymous: anonymous,
      rating: rating,
      body: bodyCtrl.text.trim(),
      date: DateTime.now().toIso8601String().substring(0, 10),
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted — thanks for your feedback.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final lh = state.findUser(widget.leaseholderId);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: HomiesColors.accentSoft, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.rate_review_outlined, size: 22, color: HomiesColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Leave a review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                if (lh != null)
                  Text('About ${lh.name}', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Your honest experience helps other tenants make informed decisions.',
            style: TextStyle(fontSize: 13, color: HomiesColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 20),

          const FieldLabel('Overall rating'),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => setState(() => rating = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: i <= rating ? const Color(0xFFF6AD55) : HomiesColors.border,
                  ),
                ),
              ),
          ]),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                const ['', 'Poor', 'Below average', 'Average', 'Good', 'Excellent'][rating],
                style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
              ),
            ),
          ),
          const SizedBox(height: 16),

          FieldLabel('Your experience${bodyCtrl.text.length < 10 ? " (min 10 chars)" : ""}'),
          TextField(
            controller: bodyCtrl,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'How was communication, maintenance response, respect of privacy, fairness…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),

          InkWell(
            onTap: () => setState(() => anonymous = !anonymous),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: anonymous ? HomiesColors.accentSoft : HomiesColors.surface2,
                border: Border.all(color: anonymous ? HomiesColors.accentBorder : HomiesColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(
                  anonymous ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: anonymous ? HomiesColors.accent : HomiesColors.textDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    anonymous ? 'Posting anonymously' : 'Post with your name',
                    style: TextStyle(
                      fontSize: 13,
                      color: anonymous ? HomiesColors.accentStrong : HomiesColors.text,
                      fontWeight: anonymous ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Switch(value: anonymous, onChanged: (v) => setState(() => anonymous = v)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('Submit review'),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Leaseholder report banner (marketplace — tenant view) ────────────────────

const _lhCategories = <(String, String)>[
  ('maintenance',    '🔧 Maintenance neglect'),
  ('harassment',     '⚠️ Harassment or intimidation'),
  ('bond',           '💰 Bond / deposit dispute'),
  ('entry',          '🚪 Unauthorized entry'),
  ('privacy',        '🔒 Privacy violation'),
  ('lease_breach',   '📄 Lease breach'),
  ('noise',          '🔊 Excessive noise'),
  ('discrimination', '⛔ Discrimination'),
  ('other',          '📌 Other'),
];

const _lhSeverityLabels = ['', 'Low', 'Moderate', 'Serious', 'Severe', 'Critical'];

String _lhCategoryLabel(String? cat) =>
    _lhCategories.firstWhere((e) => e.$1 == cat, orElse: () => ('', cat ?? '—')).$2;

class _LeaseholderReportBanner extends StatelessWidget {
  final User cu;
  const _LeaseholderReportBanner({required this.cu});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final lh = state.leaseholders.firstOrNull;
    final allLhComplaints = state.complaints
        .where((c) => c.kind == 'leaseholder')
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final myComplaints = allLhComplaints.where((c) => c.from == cu.id).toList();

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: HomiesColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.report_outlined, size: 22, color: HomiesColors.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Leaseholder complaints', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                lh != null ? 'Against ${lh.name}' : 'About your current leaseholder',
                style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
              ),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: const _LhComplaintModal(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomiesColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Report'),
          ),
        ]),
        const SizedBox(height: 12),

        if (allLhComplaints.isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            HomiesChip('${allLhComplaints.length} report${allLhComplaints.length == 1 ? '' : 's'} total'),
            HomiesChip('${allLhComplaints.where((c) => c.status == 'open').length} open', tone: ChipTone.warn),
            HomiesChip('${myComplaints.length} filed by you', tone: ChipTone.neutral),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text('RECENT REPORTS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.7)),
          const SizedBox(height: 8),
          for (final c in allLhComplaints.take(3))
            _LhReportTile(complaint: c, isOwn: c.from == cu.id),
          if (allLhComplaints.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${allLhComplaints.length - 3} more — view in Complaints',
                style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
              ),
            ),
        ] else
          const Text(
            'No reports yet. If you experience maintenance neglect, harassment, bond disputes or lease breaches — file a formal report here.',
            style: TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.4),
          ),
      ]),
    );
  }
}

class _LhReportTile extends StatelessWidget {
  final Complaint complaint;
  final bool isOwn;
  const _LhReportTile({required this.complaint, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final sev = c.severity.clamp(1, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwn ? HomiesColors.accentSoft : HomiesColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOwn ? HomiesColors.accentBorder : HomiesColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (c.category != null) HomiesChip(_lhCategoryLabel(c.category)),
              HomiesChip(
                '${_lhSeverityLabels[sev]} · $sev/5',
                tone: sev >= 4 ? ChipTone.danger : sev == 3 ? ChipTone.warn : ChipTone.neutral,
              ),
              HomiesChip(
                c.status,
                tone: c.status == 'open' ? ChipTone.warn : c.status == 'actioned' ? ChipTone.ok : ChipTone.neutral,
              ),
            ]),
          ),
          Text(fmtDate(c.date), style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
        ]),
        const SizedBox(height: 6),
        Text(
          c.anonymous ? '(Anonymous) ${c.reason}' : c.reason,
          style: const TextStyle(fontSize: 12, height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (isOwn)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Filed by you',
                style: TextStyle(fontSize: 11, color: HomiesColors.accent, fontWeight: FontWeight.w500)),
          ),
      ]),
    );
  }
}

// ─── Leaseholder complaint modal ──────────────────────────────────────────────

class _LhComplaintModal extends StatefulWidget {
  const _LhComplaintModal();

  @override
  State<_LhComplaintModal> createState() => _LhComplaintModalState();
}

class _LhComplaintModalState extends State<_LhComplaintModal> {
  late HomiesState state;
  String? category;
  int severity = 2;
  String? incidentDate;
  final descCtrl = TextEditingController();
  Attachment? evidence;
  bool anonymous = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    state = HomiesScope.of(context);
    category ??= _lhCategories.first.$1;
  }

  @override
  void dispose() {
    descCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => descCtrl.text.trim().length >= 10 && category != null;

  void _submit() {
    final cu = state.currentUser!;
    final lh = state.leaseholders.firstOrNull;
    if (lh == null) return;
    final now = DateTime.now();
    state.mutate(() => state.complaints.insert(
          0,
          Complaint(
            id: 'lhc-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
            against: lh.id,
            from: cu.id,
            reason: descCtrl.text.trim(),
            severity: severity,
            date: now.toIso8601String().substring(0, 10),
            kind: 'leaseholder',
            category: category,
            incidentDate: incidentDate,
            anonymous: anonymous,
            evidence: evidence,
          ),
        ));
    state.addAppNotification(AppNotification(
      id: 'lhc_${now.millisecondsSinceEpoch}_${lh.id}',
      kind: 'complaint',
      title: 'New leaseholder complaint received',
      body: '${anonymous ? 'A tenant' : cu.name} filed a report: ${_lhCategoryLabel(category)}.',
      at: now.toIso8601String(),
      forUserId: lh.id,
    ));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. The leaseholder has been notified.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lh = state.leaseholders.firstOrNull;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: HomiesColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.report_outlined, size: 22, color: HomiesColors.danger),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Report a leaseholder issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    if (lh != null)
                      Text('Against ${lh.name}', style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
              const Text(
                'This is a formal record. Be factual and specific — vague reports are harder to action.',
                style: TextStyle(fontSize: 13, color: HomiesColors.textDim, height: 1.4),
              ),
              const SizedBox(height: 20),

              const FieldLabel('Type of issue'),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: [
                  for (final c in _lhCategories)
                    DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => category = v),
              ),
              const SizedBox(height: 16),

              const FieldLabel('Severity'),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 1; i <= 5; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => severity = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: severity == i
                              ? (i >= 4 ? HomiesColors.danger : i == 3 ? HomiesColors.warn : HomiesColors.accent)
                              : HomiesColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: severity == i
                                ? (i >= 4 ? HomiesColors.dangerBorder : i == 3 ? HomiesColors.warnBorder : HomiesColors.accentBorder)
                                : HomiesColors.border,
                          ),
                        ),
                        child: Column(children: [
                          Text(
                            '$i',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: severity == i ? Colors.white : HomiesColors.textDim,
                            ),
                          ),
                          Text(
                            _lhSeverityLabels[i],
                            style: TextStyle(
                              fontSize: 9,
                              color: severity == i ? Colors.white.withValues(alpha: 0.85) : HomiesColors.textFaint,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),

              const FieldLabel('Date of incident'),
              InkWell(
                onTap: () async {
                  final d = await pickDate(context, initial: parseIso(incidentDate));
                  if (d != null) setState(() => incidentDate = toIso(d));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    incidentDate != null ? fmtDate(incidentDate) : 'When did this happen?',
                    style: TextStyle(color: incidentDate != null ? HomiesColors.text : HomiesColors.textFaint),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              FieldLabel('What happened?${descCtrl.text.length < 10 ? " (min 10 chars)" : ""}'),
              TextField(
                controller: descCtrl,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Be specific — when, where, what exactly happened. Include any witnesses or prior attempts to resolve.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              const FieldLabel('Evidence (optional)'),
              FilePickerButton(
                value: evidence,
                label: 'Attach photo, video or document',
                onChanged: (f) => setState(() => evidence = f),
              ),
              const Hint('Photos, PDFs, screenshots — anything that supports your report.'),
              const SizedBox(height: 16),

              InkWell(
                onTap: () => setState(() => anonymous = !anonymous),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: anonymous ? HomiesColors.accentSoft : HomiesColors.surface2,
                    border: Border.all(color: anonymous ? HomiesColors.accentBorder : HomiesColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(
                      anonymous ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: anonymous ? HomiesColors.accent : HomiesColors.textDim,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'File anonymously',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: anonymous ? HomiesColors.accentStrong : HomiesColors.text,
                          ),
                        ),
                        Text(
                          anonymous
                              ? 'Your name is hidden from the leaseholder.'
                              : 'Your name will be visible to the leaseholder.',
                          style: const TextStyle(fontSize: 11, color: HomiesColors.textDim),
                        ),
                      ]),
                    ),
                    Switch(value: anonymous, onChanged: (v) => setState(() => anonymous = v)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomiesColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit report'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
