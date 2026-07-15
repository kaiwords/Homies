import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../state/performance.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/lifestyle_fields.dart';
import '../widgets/media_viewer.dart';
import '../widgets/ui_kit.dart';

String _pid(String prefix) =>
    '$prefix-${Random().nextInt(0xFFFFFF).toRadixString(36)}';

String _clock(String iso) {
  final d = parseIso(iso);
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

({ChipTone tone, Color color}) _bandTone(String band) {
  switch (band) {
    case 'Good':
      return (tone: ChipTone.ok, color: HomiesColors.ok);
    case 'Fair':
      return (tone: ChipTone.warn, color: HomiesColors.warn);
    default:
      return (tone: ChipTone.danger, color: HomiesColors.danger);
  }
}

String _pct(double? r) => r == null ? '—' : '${(r * 100).round()}%';

/// All messages for one post conversation, between the poster and one other
/// participant, ordered oldest-first.
List<PostMessage> threadMessages(
  HomiesState s,
  String listingId,
  String posterId,
  String otherId,
) {
  final a = {posterId, otherId};
  return s.postMessages
      .where(
        (m) =>
            m.listingId == listingId &&
            {m.from, m.to}.containsAll(a) &&
            a.containsAll({m.from, m.to}),
      )
      .toList()
    ..sort((x, y) => x.at.compareTo(y.at));
}

class PostThreadScreen extends StatefulWidget {
  final Listing listing;
  final String otherUserId;
  // When set, the thread is between initiatorId ↔ otherUserId (not listing.by ↔ otherUserId).
  // Use this for leaseholder-to-leaseholder threads on a tenant's listing.
  final String? initiatorId;
  const PostThreadScreen({
    super.key,
    required this.listing,
    required this.otherUserId,
    this.initiatorId,
  });

  @override
  State<PostThreadScreen> createState() => _PostThreadScreenState();
}

class _PostThreadScreenState extends State<PostThreadScreen> {
  final _draftCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Attachment? _pendingPhoto;

  @override
  void dispose() {
    _draftCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // For L2L threads the "poster" role is taken by the initiator, not listing.by.
  String get _posterId => widget.initiatorId ?? widget.listing.by;

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    });
  }

  void _append(
    HomiesState state,
    String to, {
    String text = '',
    String kind = 'text',
    PerfSnapshot? perf,
    Attachment? attachment,
  }) {
    final cu = state.currentUser!;
    state.mutate(() {
      state.postMessages.add(
        PostMessage(
          id: _pid('pm'),
          listingId: widget.listing.id,
          from: cu.id,
          to: to,
          text: text,
          at: DateTime.now().toIso8601String(),
          kind: kind,
          perf: perf,
          attachment: attachment,
        ),
      );
    });
    _jumpToEnd();
  }

  void _send(HomiesState state, String otherId) {
    final text = _draftCtrl.text.trim();
    if (text.isEmpty && _pendingPhoto == null) return;
    _append(state, otherId, text: text, attachment: _pendingPhoto);
    _draftCtrl.clear();
    setState(() => _pendingPhoto = null);
  }

  // Future<void> _pickPhoto() async {
  //   final result = await FilePicker.platform.pickFiles(
  //     type: FileType.custom,
  //     allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
  //     withData: true,
  //   );
  //   if (result == null || result.files.isEmpty) return;
  //   final f = result.files.first;
  //   if (f.bytes == null) return;
  //   if (f.size > 2 * 1024 * 1024) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Image too large — keep it under 2 MB.')),
  //       );
  //     }
  //     return;
  //   }
  //   final ext = (f.extension ?? '').toLowerCase();
  //   final type = switch (ext) {
  //     'jpg' || 'jpeg' => 'image/jpeg',
  //     'png' => 'image/png',
  //     'gif' => 'image/gif',
  //     'webp' => 'image/webp',
  //     _ => 'image/jpeg',
  //   };
  //   setState(() {
  //     _pendingPhoto = Attachment(
  //       fileName: f.name,
  //       dataUrl: 'data:$type;base64,${base64Encode(f.bytes!)}',
  //       type: type,
  //       size: f.size,
  //       uploadedAt: DateTime.now().toIso8601String(),
  //     );
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    // The other participant from the current user's perspective.
    final otherId = cu.id == _posterId ? widget.otherUserId : _posterId;
    final other = state.findUser(otherId);
    final messages = threadMessages(
      state,
      widget.listing.id,
      _posterId,
      widget.otherUserId,
    );

    final iAmLeaseholder = cu.role == 'leaseholder';
    final otherIsTenant = other?.role == 'tenant';
    final otherIsLeaseholder = other?.role == 'leaseholder';

    // A pending request addressed to me that I haven't answered with a share yet.
    final lastRequestToMe = messages.lastWhereOrNull(
      (m) => m.kind == 'perf-request' && m.to == cu.id,
    );
    final sharedAfterRequest =
        lastRequestToMe != null &&
        messages.any(
          (m) =>
              m.kind == 'perf-share' &&
              m.from == cu.id &&
              m.at.compareTo(lastRequestToMe.at) >= 0,
        );
    final showShareAction = lastRequestToMe != null && !sharedAfterRequest;

    _jumpToEnd();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar.sm(other),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    other?.name ?? 'Conversation',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Re: ${widget.listing.title}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomiesColors.textDim,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _PostContextBar(listing: widget.listing),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet — say hi 👋',
                        style: TextStyle(color: HomiesColors.textDim),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      itemCount: messages.length,
                      itemBuilder: (_, i) => _MessageRow(
                        message: messages[i],
                        currentUser: cu,
                        sender: state.findUser(messages[i].from),
                      ),
                    ),
            ),
            if (iAmLeaseholder && otherIsTenant)
              _RequestPerfBar(
                label: 'Ask for performance reference',
                onRequest: () =>
                    _requestPerformance(state, otherId, aboutTenant: false),
              ),
            if (iAmLeaseholder && otherIsLeaseholder)
              _RequestPerfBar(
                label: 'Ask about a tenant’s track record',
                onRequest: () =>
                    _requestPerformance(state, otherId, aboutTenant: true),
              ),
            if (showShareAction)
              _SharePerfBar(
                asLeaseholder: iAmLeaseholder,
                onShare: () => _sharePerformance(state, lastRequestToMe.from),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: HomiesColors.surface,
                border: Border(top: BorderSide(color: HomiesColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pendingPhoto != null)
                    _PendingPhotoPreview(
                      attachment: _pendingPhoto!,
                      onRemove: () => setState(() => _pendingPhoto = null),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.photo_outlined,
                          size: 22,
                          color: HomiesColors.textDim,
                        ),
                        tooltip: 'Send photo',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {},
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _draftCtrl,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: 'Type a message…',
                          ),
                          onSubmitted: (_) => _send(state, otherId),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _send(state, otherId),
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requestPerformance(
    HomiesState state,
    String toId, {
    required bool aboutTenant,
  }) {
    final cu = state.currentUser!;
    final first = cu.name.split(' ').first;
    final text = aboutTenant
        ? '$first asked about one of your tenants’ track record.'
        : '$first asked for your housemate track record.';
    _append(state, toId, kind: 'perf-request', text: text);
  }

  void _sharePerformance(HomiesState state, String requesterId) async {
    final cu = state.currentUser!;

    // A leaseholder responds by vouching for one of their tenants; a tenant
    // responds with their own record.
    if (cu.role == 'leaseholder') {
      final tenants = state.users
          .where((u) => u.role == 'tenant' && !u.pending)
          .toList();
      final result =
          await showModalBottomSheet<({String tenantId, String note})>(
            context: context,
            isScrollControlled: true,
            builder: (_) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _ShareTenantRefModal(tenants: tenants),
            ),
          );
      if (result == null) return;
      final tenant = state.findUser(result.tenantId);
      if (tenant == null) return;
      final snap = snapshotFor(
        tenant,
        state,
        note: result.note.trim().isEmpty ? null : result.note.trim(),
      );
      snap.subject = tenant.name;
      snap.subjectId = tenant.id;
      _append(
        state,
        requesterId,
        kind: 'perf-share',
        text: 'Shared a reference for ${tenant.name}.',
        perf: snap,
      );
      return;
    }

    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _ShareNoteModal(),
      ),
    );
    if (note == null) return; // cancelled
    final snap = snapshotFor(
      cu,
      state,
      note: note.trim().isEmpty ? null : note.trim(),
    );
    _append(
      state,
      requesterId,
      kind: 'perf-share',
      text: 'Shared a housemate reference.',
      perf: snap,
    );
  }
}

class _PostContextBar extends StatelessWidget {
  final Listing listing;
  const _PostContextBar({required this.listing});

  @override
  Widget build(BuildContext context) {
    final amount = listing.type == 'tenant-wanted'
        ? listing.rent
        : listing.budget;
    final amountLabel = listing.type == 'tenant-wanted' ? '/wk' : ' budget';
    return Container(
      width: double.infinity,
      color: HomiesColors.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.home_work_outlined,
            size: 16,
            color: HomiesColors.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${listing.title} · ${listing.suburb}',
              style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 8),
            HomiesChip('${fmtAUD(amount)}$amountLabel', tone: ChipTone.accent),
          ],
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final PostMessage message;
  final User currentUser;
  final User? sender;
  const _MessageRow({
    required this.message,
    required this.currentUser,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    if (message.kind == 'perf-request') {
      return _EventPill(
        icon: Icons.workspace_premium_outlined,
        emoji: '🔖',
        fg: HomiesColors.accentStrong,
        bg: HomiesColors.accentSoft,
        text: message.text,
      );
    }
    if (message.kind == 'inspection-invite') {
      return _EventPill(
        icon: Icons.calendar_month_outlined,
        emoji: '📅',
        fg: HomiesColors.accent,
        bg: HomiesColors.accentSoft,
        text: message.text,
      );
    }
    if (message.kind == 'inspection-confirm') {
      return _EventPill(
        icon: Icons.check_circle_outline,
        emoji: '✅',
        fg: HomiesColors.ok,
        bg: HomiesColors.okSoft,
        text: message.text,
      );
    }

    final mine = message.from == currentUser.id;
    final align = mine ? MainAxisAlignment.end : MainAxisAlignment.start;

    Widget content;
    if (message.kind == 'perf-share' && message.perf != null) {
      content = PerfCard(snapshot: message.perf!, senderName: sender?.name);
    } else if (message.attachment != null) {
      content = _PhotoMessage(
        attachment: message.attachment!,
        text: message.text,
        mine: mine,
        senderName: mine ? null : sender?.name,
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? HomiesColors.accent : HomiesColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                sender?.name ?? '—',
                style: const TextStyle(
                  fontSize: 11,
                  color: HomiesColors.textDim,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : HomiesColors.text,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: align,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) Avatar.sm(sender),
              if (!mine) const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.80,
                ),
                child: content,
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              left: mine ? 0 : 32,
              right: mine ? 2 : 0,
            ),
            child: Text(
              _clock(message.at),
              style: const TextStyle(
                fontSize: 10,
                color: HomiesColors.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final Color fg;
  final Color bg;
  final String text;
  const _EventPill({
    required this.icon,
    required this.emoji,
    required this.fg,
    required this.bg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$emoji $text',
                  style: TextStyle(
                    fontSize: 12,
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shareable housemate-reference card. Used inside a perf-share bubble.
class PerfCard extends StatelessWidget {
  final PerfSnapshot snapshot;
  final String? senderName;
  const PerfCard({super.key, required this.snapshot, this.senderName});

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final band = _bandTone(s.band);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        border: Border.all(color: HomiesColors.borderStrong),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: HomiesColors.surface2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: HomiesColors.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 18,
                  color: HomiesColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.subject != null && s.subject!.isNotEmpty
                        ? 'Reference · ${s.subject}'
                        : 'Housemate reference',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: HomiesColors.text,
                    ),
                  ),
                ),
                HomiesChip(s.band, tone: band.tone),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PerfDonut(snapshot: s),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _row(
                  '🧹 Chores',
                  '${s.doneCount}/${s.taskCount} · ${_pct(s.choreRate)}',
                ),
                _row(
                  '💡 Bills paid',
                  '${s.paidCount}/${s.billCount} · ${_pct(s.billRate)}',
                ),
                _row(
                  '🚩 Complaints',
                  s.complaintSeverity == 0
                      ? 'None'
                      : '${s.complaintSeverity} pts',
                ),
                _row('🎉 Parties hosted', '${s.partiesHosted}'),
                if (s.lifestyle != null) ..._lifestyleRows(s.lifestyle!),
                if (s.house.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'From ${s.house}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomiesColors.textFaint,
                    ),
                  ),
                ],
                if (s.note != null && s.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HomiesColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '”${s.note}”',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HomiesColors.text,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomiesColors.text,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );

  List<Widget> _lifestyleRows(Lifestyle l) {
    final items = <(String, String)>[
      if (l.smoking.isNotEmpty)
        ('🚬 Smoking', labelFor(smokingOptions, l.smoking)),
      if (l.alcohol.isNotEmpty)
        ('🍺 Alcohol', labelFor(alcoholOptions, l.alcohol)),
      if (l.drugs.isNotEmpty) ('💊 Drugs', labelFor(drugsOptions, l.drugs)),
      if (l.pets.isNotEmpty) ('🐾 Pets', labelFor(petsOptions, l.pets)),
      if (l.cleanliness.isNotEmpty)
        ('🧽 Cleanliness', labelFor(cleanlinessOptions, l.cleanliness)),
      if (l.schedule.isNotEmpty)
        ('🕐 Daily rhythm', labelFor(scheduleOptions, l.schedule)),
      if (l.guests.isNotEmpty)
        ('🏠 Overnight guests', labelFor(guestsOptions, l.guests)),
      if (l.diet.isNotEmpty) ('🥗 Diet', labelFor(dietOptions, l.diet)),
      if (l.occupation.isNotEmpty) ('💼 Occupation', l.occupation),
    ];
    if (items.isEmpty) return [];
    return [
      const SizedBox(height: 8),
      const Divider(height: 1, color: HomiesColors.border),
      const SizedBox(height: 6),
      const Text(
        'Lifestyle',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: HomiesColors.textDim,
        ),
      ),
      const SizedBox(height: 4),
      for (final item in items) _row(item.$1, item.$2),
    ];
  }
}

class _RequestPerfBar extends StatelessWidget {
  final VoidCallback onRequest;
  final String label;
  const _RequestPerfBar({required this.onRequest, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: HomiesColors.surface,
        border: Border(top: BorderSide(color: HomiesColors.border)),
      ),
      child: OutlinedButton.icon(
        onPressed: onRequest,
        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _SharePerfBar extends StatelessWidget {
  final VoidCallback onShare;
  final bool asLeaseholder;
  const _SharePerfBar({required this.onShare, required this.asLeaseholder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: HomiesColors.accentSoft,
        border: const Border(top: BorderSide(color: HomiesColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              asLeaseholder
                  ? 'A leaseholder asked about one of your tenants.'
                  : 'A leaseholder asked for your track record.',
              style: const TextStyle(
                fontSize: 12,
                color: HomiesColors.accentStrong,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.workspace_premium_rounded, size: 16),
            label: Text(
              asLeaseholder ? 'Share a tenant' : 'Share my performance',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareNoteModal extends StatefulWidget {
  const _ShareNoteModal();
  @override
  State<_ShareNoteModal> createState() => _ShareNoteModalState();
}

class _ShareNoteModalState extends State<_ShareNoteModal> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share your performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your chores, bills, complaints and standing from your current house are attached automatically.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const FieldLabel('Add a note (optional)'),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Always paid on time, happy to give a reference…',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _ctrl.text),
                  child: const Text('Share reference'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a leaseholder pick which of their tenants to vouch for, then add a
/// note, when another leaseholder asks about a tenant's performance.
class _ShareTenantRefModal extends StatefulWidget {
  final List<User> tenants;
  const _ShareTenantRefModal({required this.tenants});

  @override
  State<_ShareTenantRefModal> createState() => _ShareTenantRefModalState();
}

class _ShareTenantRefModalState extends State<_ShareTenantRefModal> {
  String? _tenantId;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share a tenant reference',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              "Pick one of your tenants. Their live track record (chores, bills, complaints) is attached automatically.",
              style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (widget.tenants.isEmpty)
              const EmptyState(
                title: 'No tenants to vouch for',
                body:
                    'Once tenants join your house you can share their references.',
              )
            else ...[
              const FieldLabel('Tenant'),
              for (final t in widget.tenants)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _tenantId = t.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          _tenantId == t.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: _tenantId == t.id
                              ? HomiesColors.accent
                              : HomiesColors.textFaint,
                        ),
                        const SizedBox(width: 10),
                        Avatar.sm(t),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              const FieldLabel('Add a note (optional)'),
              TextField(
                controller: _ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Reliable with rent, tidy, would happily house again…',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _tenantId == null
                        ? null
                        : () => Navigator.pop(context, (
                            tenantId: _tenantId!,
                            note: _ctrl.text,
                          )),
                    child: const Text('Share reference'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Photo helpers ───────────────────────────────────────────────────────────

Uint8List? _decodeBytes(Attachment a) {
  final url = a.dataUrl;
  if (url == null || !url.startsWith('data:')) return null;
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Strip above the input bar showing the staged photo before it's sent.
class _PendingPhotoPreview extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;
  const _PendingPhotoPreview({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBytes(attachment);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: HomiesColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_outlined,
                color: HomiesColors.textFaint,
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 16,
              color: HomiesColors.textDim,
            ),
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Chat bubble that shows an image (+ optional caption text below it).
class _PhotoMessage extends StatelessWidget {
  final Attachment attachment;
  final String text;
  final bool mine;
  final String? senderName;
  const _PhotoMessage({
    required this.attachment,
    required this.text,
    required this.mine,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBytes(attachment);
    final bg = mine ? HomiesColors.accent : HomiesColors.surface2;
    final textColor = mine ? Colors.white : HomiesColors.text;

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (senderName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 2),
            child: Text(
              senderName!,
              style: const TextStyle(
                fontSize: 11,
                color: HomiesColors.textDim,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        GestureDetector(
          onTap: bytes == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => FullscreenImageViewer(
                      bytes: bytes,
                      fileName: attachment.fileName,
                      mimeType: attachment.type,
                    ),
                  ),
                ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: bytes != null
                ? Image.memory(bytes, width: 220, fit: BoxFit.fitWidth)
                : Container(
                    width: 220,
                    height: 140,
                    color: HomiesColors.surface2,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: HomiesColors.textFaint,
                      size: 40,
                    ),
                  ),
          ),
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(text, style: TextStyle(color: textColor, fontSize: 14)),
          ),
        ],
      ],
    );
  }
}

// ─── Donut chart ─────────────────────────────────────────────────────────────

class _PerfDonut extends StatelessWidget {
  final PerfSnapshot snapshot;
  const _PerfDonut({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final band = _bandTone(snapshot.band);
    final choreScore = (snapshot.choreRate ?? 1.0) * 45;
    final billScore = (snapshot.billRate ?? 1.0) * 30;
    final conductScore =
        (1 - (snapshot.complaintSeverity / 100).clamp(0.0, 1.0)) * 25;

    return Column(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CustomPaint(
            painter: _DonutPainter(
              choreScore: choreScore,
              billScore: billScore,
              conductScore: conductScore,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${snapshot.standing}',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: band.color,
                      height: 1,
                    ),
                  ),
                  const Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 9,
                      color: HomiesColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          children: const [
            _LegendDot(color: HomiesColors.ok, label: 'Chores 45'),
            _LegendDot(color: Color(0xFF4A90D9), label: 'Bills 30'),
            _LegendDot(color: HomiesColors.warn, label: 'Conduct 25'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: HomiesColors.textDim),
      ),
    ],
  );
}

class _DonutPainter extends CustomPainter {
  final double choreScore;
  final double billScore;
  final double conductScore;

  static const _strokeWidth = 14.0;
  static const _billColor = Color(0xFF4A90D9);

  const _DonutPainter({
    required this.choreScore,
    required this.billScore,
    required this.conductScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - _strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -pi / 2;
    const full = 2 * pi;

    canvas.drawArc(
      rect,
      0,
      full,
      false,
      Paint()
        ..color = HomiesColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );

    Paint slicePaint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.butt;

    double cursor = startAngle;

    void arc(double value, Color color) {
      if (value < 0.5) return;
      final sweep = (value / 100) * full;
      canvas.drawArc(rect, cursor, sweep, false, slicePaint(color));
      cursor += sweep;
    }

    arc(choreScore, HomiesColors.ok);
    arc(billScore, _billColor);
    arc(conductScore, HomiesColors.warn);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.choreScore != choreScore ||
      old.billScore != billScore ||
      old.conductScore != conductScore;
}
