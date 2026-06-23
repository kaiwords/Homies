import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

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
        padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 10),
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
          if (isLeaseholder) const _LeaseVerificationSection(),
          if (!isLeaseholder)
            const InfoBanner(
              icon: Icons.info_outline,
              text: 'Only the leaseholder can edit property & lease details. Speak to them if anything looks off.',
            ),
        ]),
      ),
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
