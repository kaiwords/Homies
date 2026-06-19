import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

/// Where a leaseholder submits their lease agreement + contact details for the
/// platform admin to verify.
class LeaseVerificationScreen extends StatefulWidget {
  const LeaseVerificationScreen({super.key});

  @override
  State<LeaseVerificationScreen> createState() => _LeaseVerificationScreenState();
}

class _LeaseVerificationScreenState extends State<LeaseVerificationScreen> {
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHead(
            title: 'Lease verification',
            subtitle: 'Submit your lease agreement so the Homies admin can verify you as a leaseholder.',
          ),
          _StatusBanner(status: status, note: v?.note, reviewedAt: v?.reviewedAt),
          const SizedBox(height: 8),
          HomiesCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Your details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const FieldLabel('Full name (as on the lease)'),
              TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Full legal name')),
              const SizedBox(height: 12),
              const FieldLabel('Phone number'),
              TextField(controller: _phone, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '0400 000 000')),
              const SizedBox(height: 12),
              const FieldLabel('Email'),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'you@example.com')),
              const SizedBox(height: 16),
              const Text('Lease agreement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            ]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _canSubmit ? () => _submit(state) : null,
            child: Text(status == 'pending' ? 'Resubmit for review' : status == 'verified' ? 'Update & resubmit' : 'Submit for verification'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String? note;
  final String? reviewedAt;
  const _StatusBanner({required this.status, this.note, this.reviewedAt});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'verified':
        return _banner(Icons.verified, HomiesColors.ok, HomiesColors.okSoft,
            'Verified', 'Your lease was verified${reviewedAt != null ? ' on ${fmtDate(reviewedAt)}' : ''}.');
      case 'pending':
        return _banner(Icons.hourglass_top, HomiesColors.warn, HomiesColors.warnSoft,
            'Awaiting review', 'The admin is reviewing your submission. You’ll be verified once approved.');
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
