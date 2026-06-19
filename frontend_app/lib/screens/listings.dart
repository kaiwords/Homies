import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/lifestyle_fields.dart';
import '../widgets/ui_kit.dart';
import 'post_thread.dart';

// Fields a user can choose to share when expressing interest.
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

/// Ids of everyone (other than the poster) who has messaged on a post.
Set<String> _participantsFor(HomiesState s, Listing l) {
  final others = <String>{};
  for (final m in s.postMessages.where((m) => m.listingId == l.id)) {
    for (final id in [m.from, m.to]) {
      if (id != l.by) others.add(id);
    }
  }
  return others;
}

void _openThread(BuildContext context, Listing listing, String otherUserId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PostThreadScreen(listing: listing, otherUserId: otherUserId)),
  );
}

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String tab = 'tenant-wanted';

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';

    final listings = state.listings.where((l) => l.type == tab && l.status == 'open').toList();
    final inbox = state.listingInterests.where((i) => i.to == cu.id).toList();
    final sent = state.listingInterests.where((i) => i.from == cu.id).toList();
    final inspectionInbox = state.inspections.where((i) => i.to == cu.id).toList();
    final myInspections = state.inspections.where((i) => i.requestedBy == cu.id).toList();

    // Conversations the current user is part of, across all posts.
    final convs = _myConversations(state, cu);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Rooms & housemates',
            subtitle: isLeaseholder
                ? 'Advertise a free room, message people directly and ask for their track record.'
                : 'Browse rooms and message leaseholders directly.',
            // Only leaseholders can post a room. Everyone else browses.
            action: isLeaseholder
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
                : null,
          ),
          if (convs.isNotEmpty) ...[
            _ConversationsCard(conversations: convs),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Segment<String>(
              options: const ['tenant-wanted', 'room-wanted'],
              value: tab,
              labelFor: (t) => t == 'tenant-wanted' ? 'Rooms available' : 'People looking',
              onChanged: (t) => setState(() => tab = t),
            ),
          ),
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
        ]),
      ),
    );
  }

  List<({Listing listing, String otherId, PostMessage last})> _myConversations(HomiesState state, User cu) {
    final out = <({Listing listing, String otherId, PostMessage last})>[];
    for (final l in state.listings) {
      final isPoster = l.by == cu.id;
      // The set of "other" participants relevant to this user on this post.
      final others = <String>{};
      for (final m in state.postMessages.where((m) => m.listingId == l.id)) {
        final involvesMe = m.from == cu.id || m.to == cu.id;
        if (isPoster) {
          if (m.from != cu.id) others.add(m.from);
          if (m.to != cu.id) others.add(m.to);
        } else if (involvesMe) {
          others.add(l.by);
        }
      }
      for (final other in others) {
        final msgs = threadMessages(state, l.id, l.by, isPoster ? other : cu.id);
        if (msgs.isEmpty) continue;
        // For a non-poster, the conversation partner shown is the poster.
        final partner = isPoster ? other : l.by;
        out.add((listing: l, otherId: partner, last: msgs.last));
      }
    }
    out.sort((a, b) => b.last.at.compareTo(a.last.at));
    return out;
  }
}

class _ConversationsCard extends StatelessWidget {
  final List<({Listing listing, String otherId, PostMessage last})> conversations;
  const _ConversationsCard({required this.conversations});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    return HomiesCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.forum_outlined, size: 18, color: HomiesColors.accent),
          const SizedBox(width: 8),
          Text('Your conversations (${conversations.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        for (final c in conversations) _convTile(context, state, cu, c),
      ]),
    );
  }

  Widget _convTile(BuildContext context, HomiesState state, User cu, ({Listing listing, String otherId, PostMessage last}) c) {
    final other = state.findUser(c.otherId);
    final isPoster = c.listing.by == cu.id;
    final preview = c.last.kind == 'perf-share'
        ? '📋 Shared a performance reference'
        : c.last.kind == 'perf-request'
            ? '🔖 Performance reference requested'
            : c.last.text;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openThread(context, c.listing, isPoster ? c.otherId : cu.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Avatar(user: other),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(other?.name ?? '—',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
                Text(fmtDateShort(c.last.at), style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
              ]),
              Text(c.listing.title,
                  style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(preview,
                  style: const TextStyle(fontSize: 12, color: HomiesColors.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const Icon(Icons.chevron_right, size: 18, color: HomiesColors.textFaint),
        ]),
      ),
    );
  }
}

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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Coloured type strip.
        Container(
          height: 4,
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
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
              HomiesChip(isRoom ? 'Room available' : 'Looking', tone: isRoom ? ChipTone.accent : ChipTone.info),
            ]),
            const SizedBox(height: 12),
            Text(listing.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (isRoom && listing.rent != null) HomiesChip('${fmtAUD(listing.rent)}/wk', tone: ChipTone.accent),
              if (!isRoom && listing.budget != null) HomiesChip('Budget ${fmtAUD(listing.budget)}/wk', tone: ChipTone.accent),
              if (listing.availableFrom != null && listing.availableFrom!.isNotEmpty)
                HomiesChip('From ${fmtDate(listing.availableFrom)}'),
            ]),
            if (listing.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(listing.description, style: const TextStyle(fontSize: 13, height: 1.4, color: HomiesColors.text)),
              ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: HomiesColors.border)),
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
        Text('Your listing · no messages yet', style: TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
      ]);
    }
    final people = participants.map((id) => state.findUser(id)).whereType<User>().toList();
    return Row(children: [
      AvatarStack(users: people),
      const SizedBox(width: 10),
      Expanded(
        child: Text('${participants.length} ${participants.length == 1 ? 'person' : 'people'} messaged you',
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
    final hasThread = state.postMessages.any((m) => m.listingId == listing.id && (m.from == cu.id || m.to == cu.id));
    final bookedInspection = state.inspections.any((i) =>
        i.listingId == listing.id && i.requestedBy == cu.id && i.status != 'declined');
    return Column(children: [
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: alreadySent
                ? null
                : () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
          onPressed: bookedInspection
              ? null
              : () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => Padding(
                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: _InspectionModal(listing: listing),
                    ),
                  ),
          icon: const Icon(Icons.event_available_outlined, size: 16),
          label: Text(bookedInspection ? 'Inspection requested' : 'Book an inspection'),
        ),
      ),
    ]);
  }
}

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

    return HomiesCard(
      color: HomiesColors.surface2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Re: ${listing?.title ?? 'listing'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Padding(padding: const EdgeInsets.only(top: 4), child: HomiesChip(interest.status, tone: statusTone)),
            ]),
          ),
          Avatar.sm(from),
        ]),
        if (interest.message.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('“${interest.message}”', style: const TextStyle(fontSize: 13))),
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
                style: TextStyle(fontSize: 11, color: HomiesColors.textDim, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final f in _shareable)
              if ((interest.sharedFields[f.$1] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(f.$2, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                    Text(
                      f.$1 == 'moveInDate' ? fmtDate(interest.sharedFields[f.$1]) : interest.sharedFields[f.$1]!,
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
                  style: TextStyle(fontSize: 11, color: HomiesColors.textDim, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
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
                onPressed: () => state.mutate(() => interest.status = 'accepted'),
                child: const Text('Accept & share contact'),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _ListingModal extends StatefulWidget {
  final String type;
  const _ListingModal({required this.type});

  @override
  State<_ListingModal> createState() => _ListingModalState();
}

class _ListingModalState extends State<_ListingModal> {
  final titleCtrl = TextEditingController();
  final suburbCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  DateTime? availableFrom;

  bool get _isRoom => widget.type == 'tenant-wanted';

  @override
  void dispose() {
    titleCtrl.dispose();
    suburbCtrl.dispose();
    amountCtrl.dispose();
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(_isRoom ? 'List a room' : 'Post what you’re looking for',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const FieldLabel('Title'),
            TextField(
              controller: titleCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _isRoom ? 'Sunny double room in 4-bed house' : 'Quiet professional after a room near the city',
              ),
            ),
            const SizedBox(height: 10),
            const FieldLabel('Suburb'),
            TextField(controller: suburbCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Marrickville')),
            const SizedBox(height: 10),
            FieldLabel(_isRoom ? 'Rent (\$/week)' : 'Budget (\$/week)'),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0')),
            const SizedBox(height: 10),
            FieldLabel(_isRoom ? 'Available from' : 'Move in by'),
            OutlinedButton(
              onPressed: () async {
                final d = await pickDate(context, initial: availableFrom);
                if (d != null) setState(() => availableFrom = d);
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(availableFrom == null ? 'Pick a date' : fmtDate(toIso(availableFrom))),
              ),
            ),
            const SizedBox(height: 10),
            const FieldLabel('Description'),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'A bit about the place / yourself…')),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: !canSave
                    ? null
                    : () {
                        final amount = double.tryParse(amountCtrl.text.trim());
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
      picked[f.$1] = _has(cu, f.$1); // pre-tick fields that have a value
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Text('Apply for this room', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Text('Applying shares your lifestyle answers and emergency contact with the leaseholder, plus the contact details you tick below.',
                style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            const SizedBox(height: 10),
            const FieldLabel('Share these details'),
            for (final f in _shareable)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: picked[f.$1] ?? false,
                onChanged: _has(cu, f.$1) ? (v) => setState(() => picked[f.$1] = v ?? false) : null,
                title: Text(
                  _has(cu, f.$1) ? f.$2 : '${f.$2} (not set)',
                  style: TextStyle(fontSize: 14, color: _has(cu, f.$1) ? HomiesColors.text : HomiesColors.textFaint),
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
                borderColor: HomiesColors.warnSoft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Complete your profile to apply', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  const Text('Applicants share their lifestyle answers and an emergency contact with the leaseholder.',
                      style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
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
            TextField(controller: msgCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Hi! I’m interested — a bit about me…')),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

class _InspectionModal extends StatefulWidget {
  final Listing listing;
  const _InspectionModal({required this.listing});

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            const Text('Book an inspection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Text('Request a time to view ${widget.listing.title}. The leaseholder confirms or suggests another time.',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
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
            const SizedBox(height: 10),
            const FieldLabel('Preferred time'),
            TextField(controller: _slotCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'e.g. 10:00 am or after 5pm')),
            const SizedBox(height: 10),
            const FieldLabel('Note (optional)'),
            TextField(controller: _noteCtrl, maxLines: 2, decoration: const InputDecoration(hintText: 'Anything the leaseholder should know…')),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                child: const Text('Request inspection'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Inspection inspection;
  final bool incoming; // true = leaseholder reviewing a request
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
              Text(incoming ? '${other?.name ?? '—'} wants to inspect' : 'Inspection with ${other?.name ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(listing?.title ?? 'the property',
                  style: const TextStyle(color: HomiesColors.textFaint, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${fmtDate(i.date)} · ${i.slot}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 12)),
            ]),
          ),
          HomiesChip(i.status, tone: tone),
        ]),
        if (i.note.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${i.note}”', style: const TextStyle(fontSize: 12))),
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
