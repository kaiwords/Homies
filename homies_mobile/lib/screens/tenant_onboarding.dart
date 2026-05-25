import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

class TenantOnboardingScreen extends StatefulWidget {
  const TenantOnboardingScreen({super.key});

  @override
  State<TenantOnboardingScreen> createState() => _TenantOnboardingScreenState();
}

class _TenantOnboardingScreenState extends State<TenantOnboardingScreen> {
  int _step = 0;
  String _idKind = 'drivers-licence';
  Attachment? _idFile;
  String _bondMethod = 'bank-transfer';
  Attachment? _bondFile;
  String _advMethod = 'bank-transfer';
  Attachment? _advFile;
  bool _acceptedRules = false;
  String? _moveIn;

  void _finish(HomiesState state) {
    final cu = state.currentUser;
    if (cu == null) {
      context.go('/login');
      return;
    }
    final bondAmount = state.property.rentAmount * state.property.bondWeeks / state.property.maxOccupants.clamp(1, 999);
    state.mutate(() {
      cu.pending = true;
      cu.docVerified = false;
      cu.bondPaid = false;
      cu.bondAmount = (bondAmount * 100).round() / 100;
      cu.advanceRentPaid = false;
      cu.moveInDate = _moveIn ?? todayIso();
      cu.acceptedRulesAt = _acceptedRules ? todayIso() : null;
      cu.submissions = Submissions(
        idDoc: _idFile == null
            ? null
            : IdDocSubmission(
                kind: _idKind,
                fileName: _idFile!.fileName,
                dataUrl: _idFile!.dataUrl,
                type: _idFile!.type,
                size: _idFile!.size,
                uploadedAt: _idFile!.uploadedAt,
              ),
        bondProof: _bondFile == null
            ? null
            : PaymentSubmission(
                method: _bondMethod,
                fileName: _bondFile!.fileName,
                dataUrl: _bondFile!.dataUrl,
                type: _bondFile!.type,
                size: _bondFile!.size,
                uploadedAt: _bondFile!.uploadedAt,
              ),
        advanceRentProof: _advFile == null
            ? null
            : PaymentSubmission(
                method: _advMethod,
                fileName: _advFile!.fileName,
                dataUrl: _advFile!.dataUrl,
                type: _advFile!.type,
                size: _advFile!.size,
                uploadedAt: _advFile!.uploadedAt,
              ),
      );
    });
    context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final p = state.property;
    final steps = ['ID document', 'Bond', 'Advance rent', 'House rules', 'Move-in date'];
    final bondAmount = (p.rentAmount * p.bondWeeks) / p.maxOccupants.clamp(1, 999);
    final advanceAmount = (p.rentAmount * p.advanceWeeks) / p.maxOccupants.clamp(1, 999);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text("Welcome — let's get you moved in", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            Text('Step ${_step + 1} of ${steps.length} — ${steps[_step]}',
                style: const TextStyle(color: HomiesColors.textDim)),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _step ? HomiesColors.accent : HomiesColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            HomiesCard(child: _stepBody(p, bondAmount, advanceAmount, state)),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton(onPressed: _step == 0 ? null : () => setState(() => _step--), child: const Text('← Back')),
              const Spacer(),
              if (_step < steps.length - 1)
                ElevatedButton(
                  onPressed: _canContinue() ? () => setState(() => _step++) : null,
                  child: const Text('Continue →'),
                )
              else
                ElevatedButton(
                  onPressed: _moveIn != null ? () => _finish(state) : null,
                  child: const Text('Submit for approval ✓'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  bool _canContinue() {
    switch (_step) {
      case 0:
        return _idFile != null;
      case 1:
        return _bondFile != null;
      case 2:
        return _advFile != null;
      case 3:
        return _acceptedRules;
      default:
        return true;
    }
  }

  Widget _stepBody(Property p, double bondAmount, double advanceAmount, HomiesState state) {
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Upload one valid ID', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const FieldLabel('Document type'),
          DropdownButtonFormField<String>(
            initialValue: _idKind,
            items: const [
              DropdownMenuItem(value: 'drivers-licence', child: Text("Driver's licence")),
              DropdownMenuItem(value: 'passport', child: Text('Passport')),
              DropdownMenuItem(value: 'medicare', child: Text('Medicare card')),
              DropdownMenuItem(value: 'proof-of-age', child: Text('Proof of age card')),
            ],
            onChanged: (v) => setState(() => _idKind = v ?? 'drivers-licence'),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Upload image or PDF'),
          FilePickerButton(value: _idFile, onChanged: (f) => setState(() => _idFile = f)),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pay your bond — ${fmtAUD(bondAmount)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text('${p.bondWeeks} weeks of rent (your share at ${p.maxOccupants} max occupants).',
              style: const TextStyle(color: HomiesColors.textDim)),
          const SizedBox(height: 10),
          HomiesCard(
            color: HomiesColors.surface2,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pay to leaseholder', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Bank: 062-000 · 12345678', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
                ]),
              ),
              Text(fmtAUD(bondAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
            ]),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Method'),
          Segment<String>(
            options: const ['bank-transfer', 'payid', 'cash'],
            value: _bondMethod,
            labelFor: (v) => v.replaceAll('-', ' '),
            onChanged: (v) => setState(() => _bondMethod = v),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Upload proof (screenshot)'),
          FilePickerButton(value: _bondFile, onChanged: (f) => setState(() => _bondFile = f)),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pay ${p.advanceWeeks} weeks advance rent', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text('${fmtAUD(advanceAmount)} — paid up-front so you start with a buffer.',
              style: const TextStyle(color: HomiesColors.textDim)),
          const SizedBox(height: 10),
          const FieldLabel('Method'),
          Segment<String>(
            options: const ['bank-transfer', 'payid', 'cash'],
            value: _advMethod,
            labelFor: (v) => v.replaceAll('-', ' '),
            onChanged: (v) => setState(() => _advMethod = v),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Upload proof'),
          FilePickerButton(value: _advFile, onChanged: (f) => setState(() => _advFile = f)),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('House rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('You must accept these before the leaseholder will let you move in.',
              style: TextStyle(color: HomiesColors.textDim)),
          const SizedBox(height: 10),
          for (final r in state.houseRules)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${r.text}')),
          CheckboxListTile(
            value: _acceptedRules,
            onChanged: (v) => setState(() => _acceptedRules = v ?? false),
            title: const Text('I have read and agree to the house rules above.'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ]);
      case 4:
      // ignore: unreachable_switch_default
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Move-in date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('We use this to prorate your share of bills and rent.', style: TextStyle(color: HomiesColors.textDim)),
          const SizedBox(height: 10),
          const FieldLabel('Planned move-in date'),
          InkWell(
            onTap: () async {
              final d = await pickDate(context, initial: parseIso(_moveIn));
              setState(() => _moveIn = toIso(d));
            },
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Text(_moveIn != null ? fmtDate(_moveIn) : 'Pick a date',
                  style: TextStyle(color: _moveIn != null ? HomiesColors.text : HomiesColors.textFaint)),
            ),
          ),
          const SizedBox(height: 10),
          const InfoBanner(
            icon: Icons.info_outline,
            text: "After you submit, the leaseholder will be notified to approve your ID and bond proofs. You'll see status updates on your dashboard.",
          ),
        ]);
    }
  }
}
