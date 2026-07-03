import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

const _features = [
  ['balcony', 'Balcony'],
  ['garage', 'Garage / parking'],
  ['furnished', 'Furnished'],
  ['swimmingPool', 'Swimming pool'],
  ['gym', 'Gym'],
  ['airCon', 'Air conditioning'],
  ['dishwasher', 'Dishwasher'],
  ['laundry', 'In-unit laundry'],
  ['petsAllowed', 'Pets allowed'],
  ['nbn', 'NBN included'],
];

class LeaseholderOnboardingScreen extends StatefulWidget {
  const LeaseholderOnboardingScreen({super.key});

  @override
  State<LeaseholderOnboardingScreen> createState() => _LeaseholderOnboardingScreenState();
}

class _LeaseholderOnboardingScreenState extends State<LeaseholderOnboardingScreen> {
  int _step = 0;
  bool _acceptedTerms = false;
  bool _finishing = false;
  final _addressCtrl = TextEditingController();
  String _type = 'House';
  int _bedrooms = 3;
  int _bathrooms = 1;
  int _maxOccupants = 4;
  final Map<String, bool> _featureFlags = {};
  final _agentCtrl = TextEditingController();
  final _agentContactCtrl = TextEditingController();
  String? _leaseStart;
  String? _leaseEnd;
  String _rentAmount = '';
  String _rentCadence = 'weekly';
  String? _rentStart;
  int _bondWeeks = 4;
  int _advanceWeeks = 2;
  final List<TextEditingController> _ruleCtrls = [
    TextEditingController(text: 'No smoking inside the property'),
    TextEditingController(text: 'Quiet hours after 10pm'),
  ];
  final List<_InviteDraft> _invites = [_InviteDraft()];

  @override
  void dispose() {
    _addressCtrl.dispose();
    _agentCtrl.dispose();
    _agentContactCtrl.dispose();
    for (final c in _ruleCtrls) {
      c.dispose();
    }
    for (final i in _invites) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _finish(HomiesState state) async {
    setState(() => _finishing = true);
    state.mutate(() {
      state.property = Property(
        id: state.property.id,
        address: _addressCtrl.text.trim().isEmpty ? state.property.address : _addressCtrl.text.trim(),
        type: _type,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        features: Map.of(_featureFlags),
        agent: _agentCtrl.text.trim(),
        agentContact: _agentContactCtrl.text.trim(),
        leaseStart: _leaseStart,
        leaseEnd: _leaseEnd,
        rentAmount: double.tryParse(_rentAmount) ?? 0,
        rentCadence: _rentCadence,
        rentStartDate: _rentStart,
        bondWeeks: _bondWeeks,
        advanceWeeks: _advanceWeeks,
        maxOccupants: _maxOccupants,
        setupComplete: true,
      );
      state.houseRules = [
        for (var i = 0; i < _ruleCtrls.length; i++)
          if (_ruleCtrls[i].text.trim().isNotEmpty)
            HouseRule(
              id: 'r-onboard-$i',
              text: _ruleCtrls[i].text.trim(),
              addedBy: state.currentUser?.id ?? 'u1',
              addedAt: todayIso(),
            ),
      ];
      state.session = Session(userId: state.session.userId, pendingSignup: null);
      if (state.currentUser != null) {
        final cu = state.currentUser!;
        cu.pending = false;
        cu.docVerified = true;
        cu.bondPaid = true;
        cu.acceptedRulesAt = todayIso();
        cu.acceptedTermsAt = _acceptedTerms ? todayIso() : null;
      }
    });

    try {
      // Create the house doc (seeded from the local state just set above)
      // before sending invites, so createInvite() has a houseId to attach
      // them to.
      if (state.currentUser?.houseId == null) {
        await state.createHouse();
      }
      for (final i in _invites) {
        final email = i.emailCtrl.text.trim();
        if (email.isNotEmpty) {
          await state.createInvite(email: email, role: i.role);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Some setup steps failed to sync — you can retry from Housemates. ($e)')),
        );
      }
    }

    if (mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final steps = ['Property', 'Lease & agent', 'Rent & bond', 'House rules', 'Terms & conditions', 'Invite housemates'];
    final rent = double.tryParse(_rentAmount) ?? 0;
    final bondAmount = rent * _bondWeeks;
    final advanceAmount = rent * _advanceWeeks;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Set up your sharehouse', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
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
            HomiesCard(child: _stepView(bondAmount, advanceAmount, state)),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton(onPressed: _step == 0 ? null : () => setState(() => _step--), child: const Text('← Back')),
              const Spacer(),
              if (_step < steps.length - 1)
                ElevatedButton(
                  onPressed: _step == 4 && !_acceptedTerms ? null : () => setState(() => _step++),
                  child: const Text('Continue →'),
                )
              else
                ElevatedButton(
                  onPressed: _finishing ? null : () => _finish(state),
                  child: _finishing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Finish setup ✓'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _stepView(double bondAmount, double advanceAmount, HomiesState state) {
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Property details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const FieldLabel('Address'),
          TextField(controller: _addressCtrl, decoration: const InputDecoration(hintText: '12 Banksia Street, Newtown NSW 2042')),
          const SizedBox(height: 10),
          const FieldLabel('Property type'),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'House', child: Text('House')),
              DropdownMenuItem(value: 'Apartment / Unit', child: Text('Apartment / Unit')),
              DropdownMenuItem(value: 'Townhouse', child: Text('Townhouse')),
              DropdownMenuItem(value: 'Granny flat', child: Text('Granny flat')),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'House'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _intField('Bedrooms', _bedrooms, (v) => setState(() => _bedrooms = v))),
            const SizedBox(width: 8),
            Expanded(child: _intField('Bathrooms', _bathrooms, (v) => setState(() => _bathrooms = v))),
            const SizedBox(width: 8),
            Expanded(child: _intField('Max', _maxOccupants, (v) => setState(() => _maxOccupants = v))),
          ]),
          const SizedBox(height: 10),
          const FieldLabel('Features'),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final f in _features)
              FilterChip(
                label: Text(f[1]),
                selected: _featureFlags[f[0]] == true,
                onSelected: (v) => setState(() => _featureFlags[f[0]] = v),
              ),
          ]),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Lease & agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const FieldLabel('Lease start'),
          _dateField(_leaseStart, (v) => setState(() => _leaseStart = v)),
          const SizedBox(height: 10),
          const FieldLabel('Lease end'),
          _dateField(_leaseEnd, (v) => setState(() => _leaseEnd = v)),
          const SizedBox(height: 10),
          const FieldLabel('Renting through (agent / landlord)'),
          TextField(controller: _agentCtrl, decoration: const InputDecoration(hintText: 'Ray White Newtown')),
          const SizedBox(height: 10),
          const FieldLabel('Agent contact (optional)'),
          TextField(controller: _agentContactCtrl, decoration: const InputDecoration(hintText: 'leasing@example.com.au')),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Rent & bond rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const FieldLabel('Rent amount'),
          TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '850'),
              onChanged: (v) => setState(() => _rentAmount = v)),
          const SizedBox(height: 10),
          const FieldLabel('Cadence'),
          Segment<String>(
            options: const ['weekly', 'fortnightly', 'monthly'],
            value: _rentCadence,
            labelFor: (v) => v[0].toUpperCase() + v.substring(1),
            onChanged: (v) => setState(() => _rentCadence = v),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Rent start date'),
          _dateField(_rentStart, (v) => setState(() => _rentStart = v)),
          const Divider(),
          const FieldLabel('Bond required'),
          Segment<int>(
            options: const [2, 4],
            value: _bondWeeks,
            labelFor: (v) => '$v weeks',
            onChanged: (v) => setState(() => _bondWeeks = v),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Advance rent'),
          Segment<int>(
            options: const [0, 1, 2, 4],
            value: _advanceWeeks,
            labelFor: (v) => v == 0 ? 'None' : '$v weeks',
            onChanged: (v) => setState(() => _advanceWeeks = v),
          ),
          if (_rentAmount.isNotEmpty) ...[
            const SizedBox(height: 12),
            HomiesCard(
              color: HomiesColors.surface2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('A new housemate will owe before move-in:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: HomiesColors.textDim)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Bond ($_bondWeeks weeks)'),
                  Text(fmtAUD(bondAmount / _maxOccupants), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Advance rent ($_advanceWeeks weeks)'),
                  Text(fmtAUD(advanceAmount / _maxOccupants), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ],
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Initial house rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (var i = 0; i < _ruleCtrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: TextField(controller: _ruleCtrls[i])),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _ruleCtrls[i].dispose();
                    _ruleCtrls.removeAt(i);
                  }),
                ),
              ]),
            ),
          OutlinedButton(onPressed: () => setState(() => _ruleCtrls.add(TextEditingController())), child: const Text('+ Add another rule')),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Terms & conditions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('By creating a house on Homies, you agree to the following responsibilities.', style: TextStyle(color: HomiesColors.textDim)),
          const SizedBox(height: 12),
          Container(
            height: 240,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HomiesColors.surface2,
              border: Border.all(color: HomiesColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _LhTermsClause('Accurate information', 'You will provide accurate property, lease, and financial information to all housemates.'),
                _LhTermsClause('Fair administration', 'You will fairly administer bond, rent, and house rule decisions in accordance with local tenancy laws.'),
                _LhTermsClause('Terms maintenance', 'You will keep the house terms up to date and notify tenants of any changes.'),
                _LhTermsClause('Legal compliance', 'You are responsible for ensuring this arrangement complies with the applicable tenancy legislation in your state or territory.'),
                _LhTermsClause('Platform use', 'You will use Homies in good faith and not use the platform to harass, deceive, or discriminate against any housemate.', isLast: true),
              ]),
            ),
          ),
          CheckboxListTile(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            title: const Text('I have read and agree to these terms and conditions.'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ]);
      case 5:
      // ignore: unreachable_switch_default
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Invite your housemates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          for (var i = 0; i < _invites.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _invites[i].emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'housemate@example.com'),
                  ),
                ),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _invites[i].role,
                  items: const [
                    DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
                    DropdownMenuItem(value: 'leaseholder', child: Text('Co-leaseholder')),
                  ],
                  onChanged: (v) => setState(() => _invites[i].role = v ?? 'tenant'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _invites.length == 1
                      ? null
                      : () => setState(() {
                            _invites[i].dispose();
                            _invites.removeAt(i);
                          }),
                ),
              ]),
            ),
          OutlinedButton(onPressed: () => setState(() => _invites.add(_InviteDraft())), child: const Text('+ Another invite')),
        ]);
    }
  }

  Widget _intField(String label, int value, ValueChanged<int> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      TextFormField(
        initialValue: '$value',
        keyboardType: TextInputType.number,
        onChanged: (v) => onChanged(int.tryParse(v) ?? value),
      ),
    ]);
  }

  Widget _dateField(String? value, ValueChanged<String?> onChanged) {
    return InkWell(
      onTap: () async {
        final d = await pickDate(context, initial: parseIso(value));
        onChanged(toIso(d));
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Text(value != null ? fmtDate(value) : 'Pick a date',
            style: TextStyle(color: value != null ? HomiesColors.text : HomiesColors.textFaint)),
      ),
    );
  }
}

class _InviteDraft {
  final emailCtrl = TextEditingController();
  String role = 'tenant';
  void dispose() => emailCtrl.dispose();
}

class _LhTermsClause extends StatelessWidget {
  final String title;
  final String body;
  final bool isLast;
  const _LhTermsClause(this.title, this.body, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HomiesColors.text)),
        const SizedBox(height: 2),
        Text(body, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.5)),
      ]),
    );
  }
}
