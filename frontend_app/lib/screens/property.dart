import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

const _lhCategories = <(String, String)>[
  ('maintenance',  '🔧 Maintenance neglect'),
  ('harassment',   '⚠️ Harassment or intimidation'),
  ('bond',         '💰 Bond / deposit dispute'),
  ('entry',        '🚪 Unauthorized entry'),
  ('privacy',      '🔒 Privacy violation'),
  ('lease_breach', '📄 Lease breach'),
  ('noise',        '🔊 Excessive noise'),
  ('discrimination','⛔ Discrimination'),
  ('other',        '📌 Other'),
];

const _lhSeverityLabels = ['', 'Low', 'Moderate', 'Serious', 'Severe', 'Critical'];

String _lhCategoryLabel(String? cat) =>
    _lhCategories.firstWhere((e) => e.$1 == cat, orElse: () => ('', cat ?? '—')).$2;

const _featureLabels = {
  'balcony': 'Balcony',
  'garage': 'Garage / parking',
  'furnished': 'Furnished',
  'swimmingPool': 'Swimming pool',
  'gym': 'Gym',
  'airCon': 'Air conditioning',
  'dishwasher': 'Dishwasher',
  'laundry': 'In-unit laundry',
  'petsAllowed': 'Pets allowed',
  'nbn': 'NBN included',
};

class PropertyScreen extends StatelessWidget {
  const PropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final p = state.property;
    final isLeaseholder = state.currentUser?.role == 'leaseholder';
    final features = p.features.entries.where((e) => e.value).map((e) => _featureLabels[e.key] ?? e.key).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Property & lease',
            subtitle: 'The details every housemate should know.',
            action: isLeaseholder ? OutlinedButton(onPressed: () {}, child: const Text('Edit')) : null,
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.address, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('${p.type} · ${p.bedrooms} bed · ${p.bathrooms} bath · sleeps ${p.maxOccupants}',
                  style: const TextStyle(color: HomiesColors.textDim)),
              if (features.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final f in features) HomiesChip(f)]),
              ],
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Lease', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatRow(tiles: [
                StatTile(label: 'Start', value: fmtDate(p.leaseStart), valueFontSize: 16),
                StatTile(label: 'End', value: fmtDate(p.leaseEnd), valueFontSize: 16),
                StatTile(label: 'Agent', value: p.agent.isEmpty ? '—' : p.agent, valueFontSize: 14, sub: p.agentContact),
              ]),
            ]),
          ),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Rent & bond', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              StatRow(tiles: [
                StatTile(label: 'Rent', value: fmtAUD(p.rentAmount), sub: '${cadenceLabel(p.rentCadence)} · starts ${fmtDate(p.rentStartDate)}'),
                StatTile(label: 'Bond required', value: '${p.bondWeeks} weeks', sub: '≈ ${fmtAUD(p.rentAmount * p.bondWeeks)} for the property'),
                StatTile(label: 'Advance rent', value: '${p.advanceWeeks} weeks', sub: 'collected before move-in'),
              ]),
            ]),
          ),
          const _ConditionChecklistCard(),
          const _ParkingCard(),
          InkWell(
            onTap: () => context.go('/app/welcome-guide'),
            borderRadius: BorderRadius.circular(12),
            child: HomiesCard(
              child: Row(children: [
                const Icon(Icons.waving_hand_outlined, color: HomiesColors.accent, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Welcome guide', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('House orientation, contacts & tips', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: HomiesColors.textFaint, size: 18),
              ]),
            ),
          ),
          if (isLeaseholder) const _LeaseVerificationSection(),
          if (!isLeaseholder) ...[
            const InfoBanner(
              icon: Icons.info_outline,
              text: 'Only the leaseholder can edit property & lease details. Speak to them if anything looks off.',
            ),
            _TenantLeaseDocSection(state: state),
            const _LeaseholderComplaintsCard(),
          ],
        ]),
      ),
    );
  }
}

class _TenantLeaseDocSection extends StatelessWidget {
  final HomiesState state;
  const _TenantLeaseDocSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final leaseholder = state.leaseholders.firstWhereOrNull(
      (u) => u.leaseVerification?.status == 'verified' && u.leaseVerification?.agreement != null,
    );
    if (leaseholder == null) return const SizedBox.shrink();
    final agreement = leaseholder.leaseVerification!.agreement!;
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Lease agreement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const Padding(
          padding: EdgeInsets.only(top: 2, bottom: 8),
          child: Text(
            'The leaseholder has shared a copy of the signed lease.',
            style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
          ),
        ),
        AttachmentTile(value: agreement),
      ]),
    );
  }
}

class _LeaseVerificationSection extends StatefulWidget {
  const _LeaseVerificationSection();

  @override
  State<_LeaseVerificationSection> createState() => _LeaseVerificationSectionState();
}

class _LeaseVerificationSectionState extends State<_LeaseVerificationSection> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  Attachment? _agreement;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final cu = HomiesScope.of(context).currentUser;
    final v = cu?.leaseVerification;
    _name = TextEditingController(text: v?.fullName.isNotEmpty == true ? v!.fullName : (cu?.name ?? ''));
    _phone = TextEditingController(text: v?.phone.isNotEmpty == true ? v!.phone : (cu?.phone ?? ''));
    _email = TextEditingController(text: v?.email.isNotEmpty == true ? v!.email : (cu?.email ?? ''));
    _agreement = v?.agreement;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _agreement != null && _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty && _email.text.trim().isNotEmpty;

  void _submit(HomiesState state) {
    state.submitLeaseVerification(LeaseVerification(
      agreement: _agreement,
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitted for verification ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final status = cu.leaseStatus;
    final v = cu.leaseVerification;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      _LeaseStatusBanner(status: status, note: v?.note, reviewedAt: v?.reviewedAt),
      HomiesCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Lease verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              'Submit your lease agreement so the Homies admin can verify you as a leaseholder.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
            ),
          ),
          const FieldLabel('Full name (as on the lease)'),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Full legal name'),
          ),
          const SizedBox(height: 12),
          const FieldLabel('Phone number'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: '0400 000 000'),
          ),
          const SizedBox(height: 12),
          const FieldLabel('Email'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
          const SizedBox(height: 16),
          const Text('Lease agreement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 8),
            child: Text('Upload a PDF or photo of your signed lease (under 2 MB).',
                style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
          ),
          FilePickerButton(
            value: _agreement,
            label: 'Upload lease agreement',
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
            onChanged: (a) => setState(() => _agreement = a),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _canSubmit ? () => _submit(state) : null,
            child: Text(
              status == 'pending'
                  ? 'Resubmit for review'
                  : status == 'verified'
                      ? 'Update & resubmit'
                      : 'Submit for verification',
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _LeaseStatusBanner extends StatelessWidget {
  final String status;
  final String? note;
  final String? reviewedAt;
  const _LeaseStatusBanner({required this.status, this.note, this.reviewedAt});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'verified':
        return _banner(Icons.verified, HomiesColors.ok, HomiesColors.okSoft,
            'Verified', 'Your lease was verified${reviewedAt != null ? ' on ${fmtDate(reviewedAt)}' : ''}.');
      case 'pending':
        return _banner(Icons.hourglass_top, HomiesColors.warn, HomiesColors.warnSoft,
            'Awaiting review', "The admin is reviewing your submission. You'll be verified once approved.");
      case 'rejected':
        return _banner(Icons.error_outline, HomiesColors.danger, HomiesColors.dangerSoft,
            'Rejected', note != null && note!.isNotEmpty ? 'Reason: $note\nFix the issue and resubmit.' : 'Please review your details and resubmit.');
      default:
        return _banner(Icons.info_outline, HomiesColors.textDim, HomiesColors.surface2,
            'Not submitted', 'Submit your lease agreement to get verified.');
    }
  }

  Widget _banner(IconData icon, Color fg, Color bg, String title, String body) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12.5, color: HomiesColors.text, height: 1.35)),
            ]),
          ),
        ]),
      );
}

// ─── Leaseholder complaint section (tenant view) ─────────────────────────────

class _LeaseholderComplaintsCard extends StatelessWidget {
  const _LeaseholderComplaintsCard();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final leaseholder = state.leaseholders.firstOrNull;
    final mine = state.complaints
        .where((c) => c.kind == 'leaseholder' && c.from == cu.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    void openModal() => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: const _LeaseholderComplaintModal(),
          ),
        );

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
              const Text('Report a leaseholder issue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                leaseholder != null ? 'Against ${leaseholder.name}' : 'File a formal complaint',
                style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
              ),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: openModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: HomiesColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Report'),
          ),
        ]),

        if (mine.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 4),
          const Text('YOUR FILED REPORTS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.7)),
          const SizedBox(height: 8),
          for (final c in mine) _LhComplaintTile(complaint: c, state: state),
        ] else ...[
          const SizedBox(height: 12),
          const Text(
            'Formal reports are confidential and go to the house admin. Use this for maintenance neglect, harassment, bond disputes, or lease breaches.',
            style: TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.4),
          ),
        ],
      ]),
    );
  }
}

class _LhComplaintTile extends StatelessWidget {
  final Complaint complaint;
  final HomiesState state;
  const _LhComplaintTile({required this.complaint, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    final sev = c.severity.clamp(1, 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              if (c.category != null) HomiesChip(_lhCategoryLabel(c.category)),
              HomiesChip(
                '${_lhSeverityLabels[sev]} (${c.severity}/5)',
                tone: sev >= 4 ? ChipTone.danger : sev == 3 ? ChipTone.warn : ChipTone.neutral,
              ),
              HomiesChip(
                c.status == 'open' ? 'open' : c.status == 'actioned' ? 'actioned' : 'ignored',
                tone: c.status == 'open' ? ChipTone.warn : c.status == 'actioned' ? ChipTone.ok : ChipTone.neutral,
              ),
              if (c.anonymous) const HomiesChip('anonymous'),
            ]),
          ),
          Text(fmtDate(c.date), style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
        ]),
        if (c.incidentDate != null && c.incidentDate != c.date) ...[
          const SizedBox(height: 2),
          Text('Incident on ${fmtDate(c.incidentDate)}', style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
        ],
        const SizedBox(height: 6),
        Text(c.reason, style: const TextStyle(fontSize: 13, height: 1.4)),
        if (c.evidence != null) ...[
          const SizedBox(height: 6),
          AttachmentTile(value: c.evidence!, compact: true),
        ],
      ]),
    );
  }
}

// ─── Condition checklist ─────────────────────────────────────────────────────

class _ConditionChecklistCard extends StatefulWidget {
  const _ConditionChecklistCard();

  @override
  State<_ConditionChecklistCard> createState() => _ConditionChecklistCardState();
}

class _ConditionChecklistCardState extends State<_ConditionChecklistCard> {
  final _expanded = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';

    final checks = (isLeaseholder
            ? state.conditionChecks
            : state.conditionChecks.where((c) => c.userId == cu.id).toList())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Condition checks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _ConditionCheckModal(),
            ),
            child: const Text('+ New'),
          ),
        ]),
        const Text(
          'Property condition recorded at move-in and move-out.',
          style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
        ),
        if (checks.isEmpty) ...[
          const SizedBox(height: 10),
          const Text('No checks recorded yet.', style: TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
        ] else ...[
          const SizedBox(height: 12),
          for (final check in checks)
            _CheckTile(
              check: check,
              expanded: _expanded[check.id] ?? false,
              onToggle: () => setState(() => _expanded[check.id] = !(_expanded[check.id] ?? false)),
            ),
        ],
      ]),
    );
  }
}

class _CheckTile extends StatelessWidget {
  final ConditionCheck check;
  final bool expanded;
  final VoidCallback onToggle;
  const _CheckTile({required this.check, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final goodCount = check.items.where((i) => i.condition == 'good').length;
    final fairCount = check.items.where((i) => i.condition == 'fair').length;
    final poorCount = check.items.where((i) => i.condition == 'poor').length;
    final createdByUser = state.findUser(check.createdBy);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              HomiesChip(
                check.type == 'move-in' ? 'Move-in' : 'Move-out',
                tone: check.type == 'move-in' ? ChipTone.ok : ChipTone.warn,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(check.userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${fmtDate(check.createdAt)} · ${check.items.length} area${check.items.length != 1 ? 's' : ''}${createdByUser != null && createdByUser.id != check.userId ? ' · by ${createdByUser.name}' : ''}',
                    style: const TextStyle(fontSize: 11, color: HomiesColors.textDim),
                  ),
                ]),
              ),
              const SizedBox(width: 6),
              Wrap(spacing: 4, children: [
                if (goodCount > 0) HomiesChip('$goodCount ✓', tone: ChipTone.ok),
                if (fairCount > 0) HomiesChip('$fairCount ~', tone: ChipTone.warn),
                if (poorCount > 0) HomiesChip('$poorCount ✗', tone: ChipTone.danger),
              ]),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more, size: 18, color: HomiesColors.textDim),
              ),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final item in check.items) _ConditionItemRow(item: item),
              if (check.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  '"${check.notes}"',
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: HomiesColors.textDim),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ConditionItemRow extends StatelessWidget {
  final ConditionItem item;
  const _ConditionItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.condition) {
      'good' => (Icons.check_circle_outline, HomiesColors.ok),
      'fair' => (Icons.warning_amber_outlined, HomiesColors.warn),
      _ => (Icons.error_outline, HomiesColors.danger),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.area, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (item.notes.isNotEmpty)
              Text(item.notes, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
            if (item.photo != null) ...[
              const SizedBox(height: 4),
              AttachmentTile(value: item.photo!, compact: true),
            ],
          ]),
        ),
        HomiesChip(
          item.condition,
          tone: item.condition == 'good'
              ? ChipTone.ok
              : item.condition == 'fair'
                  ? ChipTone.warn
                  : ChipTone.danger,
        ),
      ]),
    );
  }
}

// ─── Condition check create modal ─────────────────────────────────────────────

class _ConditionCheckModal extends StatefulWidget {
  const _ConditionCheckModal();

  @override
  State<_ConditionCheckModal> createState() => _ConditionCheckModalState();
}

class _ConditionCheckModalState extends State<_ConditionCheckModal> {
  String _type = 'move-in';
  String? _userId;
  String? _userName;
  final List<_ItemEntry> _items = [];
  final _notesCtrl = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final cu = HomiesScope.of(context).currentUser!;
    if (cu.role != 'leaseholder') {
      _userId = cu.id;
      _userName = cu.name;
    }
  }

  @override
  void dispose() {
    for (final item in _items) { item.dispose(); }
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _userId != null &&
      _items.isNotEmpty &&
      _items.every((i) => i.areaCtrl.text.trim().isNotEmpty);

  void _save(HomiesState state) {
    final cu = state.currentUser!;
    final now = DateTime.now().toIso8601String();
    state.mutate(() {
      state.conditionChecks.add(ConditionCheck(
        id: 'cc-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
        type: _type,
        userId: _userId!,
        userName: _userName!,
        createdBy: cu.id,
        createdAt: now,
        items: _items
            .map((e) => ConditionItem(
                  id: 'ci-${Random().nextInt(0xFFFF).toRadixString(36)}',
                  area: e.areaCtrl.text.trim(),
                  condition: e.condition,
                  notes: e.notesCtrl.text.trim(),
                  photo: e.photo,
                ))
            .toList(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Condition check saved ✓')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final tenants = state.activeHousemates.where((u) => u.role == 'tenant').toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.97,
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
          const Text('New condition check', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 20),
            child: Text(
              'Record the state of each area of the property.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 13),
            ),
          ),

          const FieldLabel('Check type'),
          const SizedBox(height: 8),
          Row(children: [
            for (final (val, label) in [('move-in', 'Move-in'), ('move-out', 'Move-out')]) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _type = val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _type == val
                          ? (val == 'move-in' ? HomiesColors.okSoft : HomiesColors.warnSoft)
                          : HomiesColors.surface2,
                      border: Border.all(
                        color: _type == val
                            ? (val == 'move-in' ? HomiesColors.ok : HomiesColors.warn)
                            : HomiesColors.border,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _type == val
                            ? (val == 'move-in' ? HomiesColors.ok : HomiesColors.warn)
                            : HomiesColors.textDim,
                      ),
                    ),
                  ),
                ),
              ),
              if (val == 'move-in') const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 16),

          if (isLeaseholder) ...[
            const FieldLabel('Tenant'),
            DropdownButtonFormField<String>(
              initialValue: _userId,
              hint: const Text('Select tenant'),
              items: [
                for (final u in tenants) DropdownMenuItem(value: u.id, child: Text(u.name)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _userId = v;
                  _userName = tenants.firstWhere((u) => u.id == v).name;
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          Row(children: [
            const Expanded(
              child: Text('Areas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_ItemEntry())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add area'),
            ),
          ]),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No areas added yet. Tap "Add area" to start.',
                style: TextStyle(color: HomiesColors.textFaint, fontSize: 12),
              ),
            ),
          for (var i = 0; i < _items.length; i++)
            _ItemCard(
              entry: _items[i],
              index: i + 1,
              onRemove: () => setState(() {
                _items[i].dispose();
                _items.removeAt(i);
              }),
              onChanged: () => setState(() {}),
            ),

          const SizedBox(height: 8),
          const FieldLabel('Overall notes (optional)'),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'General observations about the property condition…'),
          ),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _canSave ? () => _save(state) : null,
                child: const Text('Save check'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ItemEntry {
  final areaCtrl = TextEditingController();
  String condition = 'good';
  final notesCtrl = TextEditingController();
  Attachment? photo;

  void dispose() {
    areaCtrl.dispose();
    notesCtrl.dispose();
  }
}

class _ItemCard extends StatefulWidget {
  final _ItemEntry entry;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _ItemCard({required this.entry, required this.index, required this.onRemove, required this.onChanged});

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiesColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomiesColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Area ${widget.index}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close, size: 18, color: HomiesColors.textFaint),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: widget.entry.areaCtrl,
          onChanged: (_) => widget.onChanged(),
          decoration: const InputDecoration(hintText: 'e.g. Kitchen, Main bedroom…', isDense: true),
        ),
        const SizedBox(height: 10),
        const Text('Condition', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
        const SizedBox(height: 6),
        Row(children: [
          for (final (val, label, tone) in [
            ('good', 'Good', HomiesColors.ok),
            ('fair', 'Fair', HomiesColors.warn),
            ('poor', 'Poor', HomiesColors.danger),
          ]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => widget.entry.condition = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: widget.entry.condition == val
                        ? tone.withValues(alpha: 0.15)
                        : HomiesColors.surface,
                    border: Border.all(
                      color: widget.entry.condition == val ? tone : HomiesColors.border,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.entry.condition == val ? tone : HomiesColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
            if (val != 'poor') const SizedBox(width: 6),
          ],
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: widget.entry.notesCtrl,
          onChanged: (_) => widget.onChanged(),
          decoration: const InputDecoration(hintText: 'Notes (optional)', isDense: true),
        ),
        const SizedBox(height: 8),
        FilePickerButton(
          value: widget.entry.photo,
          onChanged: (f) => setState(() => widget.entry.photo = f),
          label: widget.entry.photo == null ? 'Add photo' : 'Replace photo',
          allowedExtensions: ['jpg', 'jpeg', 'png'],
        ),
      ]),
    );
  }
}

// ─── Leaseholder complaint modal ──────────────────────────────────────────────

class _LeaseholderComplaintModal extends StatefulWidget {
  const _LeaseholderComplaintModal();

  @override
  State<_LeaseholderComplaintModal> createState() => _LeaseholderComplaintModalState();
}

class _LeaseholderComplaintModalState extends State<_LeaseholderComplaintModal> {
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
      const SnackBar(content: Text('Report submitted. The house admin has been notified.')),
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
              // Header
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

              // Category
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

              // Severity
              const FieldLabel('Severity'),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 1; i <= 5; i++) ...[
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
                ],
              ]),
              const SizedBox(height: 16),

              // Date of incident
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

              // Description
              FieldLabel('What happened? ${descCtrl.text.length < 10 ? "(min 10 characters)" : ""}'),
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

              // Evidence
              const FieldLabel('Evidence (optional)'),
              FilePickerButton(
                value: evidence,
                label: 'Attach photo, video or document',
                onChanged: (f) => setState(() => evidence = f),
              ),
              const Hint('Photos, PDFs, screenshots — anything that supports your report.'),
              const SizedBox(height: 16),

              // Anonymous
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
                          anonymous ? 'Your name is hidden from the leaseholder.' : 'Your name will be visible to the leaseholder.',
                          style: const TextStyle(fontSize: 11, color: HomiesColors.textDim),
                        ),
                      ]),
                    ),
                    Switch(value: anonymous, onChanged: (v) => setState(() => anonymous = v)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
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

// ── Parking schedule ─────────────────────────────────────────────────────────

const _parkingSpots = ['Driveway', 'Garage', 'Visitor spot', 'Street spot'];

class _ParkingCard extends StatelessWidget {
  const _ParkingCard();

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final todayIso = toIso(DateTime.now())!;
    final cutoff = toIso(DateTime.now().add(const Duration(days: 13)))!;

    final upcoming = state.parkingBookings
        .where((b) => b.date.compareTo(todayIso) >= 0 && b.date.compareTo(cutoff) <= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final byDate = <String, List<ParkingBooking>>{};
    for (final b in upcoming) {
      (byDate[b.date] ??= []).add(b);
    }
    final dates = byDate.keys.toList()..sort();

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: Text('Parking schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _ParkingBookSheet(),
            ),
            child: const Text('Reserve spot'),
          ),
        ]),
        const Text(
          'Reserve driveway, garage or visitor spots by date.',
          style: TextStyle(color: HomiesColors.textDim, fontSize: 12),
        ),
        if (upcoming.isEmpty) ...[
          const SizedBox(height: 10),
          const Text('No upcoming reservations.', style: TextStyle(color: HomiesColors.textFaint, fontSize: 12)),
        ] else ...[
          const SizedBox(height: 12),
          for (final date in dates) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                fmtDate(date),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HomiesColors.textFaint, letterSpacing: 0.6),
              ),
            ),
            for (final b in byDate[date]!)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: b.userId == cu.id ? HomiesColors.accentSoft : HomiesColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: b.userId == cu.id ? HomiesColors.accentBorder : HomiesColors.border,
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.local_parking_rounded, size: 16, color: HomiesColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b.spot, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        b.userId == cu.id ? 'You' : b.userName,
                        style: const TextStyle(fontSize: 12, color: HomiesColors.textDim),
                      ),
                      if (b.note?.isNotEmpty == true)
                        Text('"${b.note}"', style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint, fontStyle: FontStyle.italic)),
                    ]),
                  ),
                  if (b.userId == cu.id || isLeaseholder)
                    TextButton(
                      onPressed: () => state.mutate(() => state.parkingBookings.removeWhere((x) => x.id == b.id)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Cancel', style: TextStyle(color: HomiesColors.danger, fontSize: 12)),
                    ),
                ]),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ]),
    );
  }
}

class _ParkingBookSheet extends StatefulWidget {
  const _ParkingBookSheet();

  @override
  State<_ParkingBookSheet> createState() => _ParkingBookSheetState();
}

class _ParkingBookSheetState extends State<_ParkingBookSheet> {
  String _spot = _parkingSpots.first;
  DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final dateIso = toIso(_date)!;

    final taken = state.parkingBookings
        .where((b) => b.spot == _spot && b.date == dateIso)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
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
          const Text('Reserve a parking spot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 20),
            child: Text('Pick a spot and the date you need it.', style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
          ),

          const FieldLabel('Spot'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _parkingSpots)
                GestureDetector(
                  onTap: () => setState(() => _spot = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _spot == s ? HomiesColors.accentSoft : HomiesColors.surface2,
                      border: Border.all(color: _spot == s ? HomiesColors.accentBorder : HomiesColors.border),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _spot == s ? HomiesColors.accentStrong : HomiesColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          const FieldLabel('Date'),
          InkWell(
            onTap: () async {
              final d = await pickDate(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Text(fmtDate(dateIso)),
            ),
          ),

          if (taken.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HomiesColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HomiesColors.dangerBorder),
              ),
              child: Text(
                'Already reserved by ${taken.map((b) => b.userName).join(', ')} on this date.',
                style: const TextStyle(color: HomiesColors.danger, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),

          const FieldLabel('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'e.g. getting a delivery'),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              state.mutate(() {
                state.parkingBookings.add(ParkingBooking(
                  id: 'pk-${Random().nextInt(0xFFFFFF).toRadixString(36)}',
                  spot: _spot,
                  userId: cu.id,
                  userName: cu.name,
                  date: dateIso,
                  note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                  createdAt: DateTime.now().toIso8601String(),
                ));
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$_spot reserved for ${fmtDate(dateIso)}')),
              );
            },
            child: const Text('Confirm reservation'),
          ),
        ]),
      ),
    );
  }
}
