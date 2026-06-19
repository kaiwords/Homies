import 'package:flutter/material.dart';

import '../state/models.dart';
import '../theme.dart';
import 'ui_kit.dart';

// Shared option sets so the editor and the read-only summary speak the same
// language. `value` is what we persist; `label` is what we show.
const smokingOptions = [
  ('non-smoker', 'Non-smoker'),
  ('outside-only', 'Outside only'),
  ('smoker', 'Smoker'),
];
const alcoholOptions = [
  ('none', "Don't drink"),
  ('social', 'Socially'),
  ('regular', 'Regularly'),
];
const relationshipOptions = [
  ('single', 'Single'),
  ('relationship', 'In a relationship'),
  ('married', 'Married'),
];
const petsOptions = [
  ('none', 'No pets'),
  ('has-pets', 'Have pet(s)'),
];
const scheduleOptions = [
  ('early-bird', 'Early bird'),
  ('flexible', 'Flexible'),
  ('night-owl', 'Night owl'),
];
const guestsOptions = [
  ('rarely', 'Rarely'),
  ('sometimes', 'Sometimes'),
  ('often', 'Often'),
];
const dietOptions = [
  ('none', 'No preference'),
  ('vegetarian', 'Vegetarian'),
  ('vegan', 'Vegan'),
  ('halal', 'Halal'),
  ('other', 'Other'),
];

String labelFor(List<(String, String)> options, String value) =>
    options.firstWhere((o) => o.$1 == value, orElse: () => (value, value)).$2;

/// A self-contained editor for the lifestyle questionnaire + emergency contact.
/// It keeps its own working copies and notifies the parent on every change.
class LifestyleEmergencyForm extends StatefulWidget {
  final Lifestyle? lifestyle;
  final EmergencyContact? emergency;
  final void Function(Lifestyle lifestyle, EmergencyContact emergency) onChanged;
  const LifestyleEmergencyForm({super.key, this.lifestyle, this.emergency, required this.onChanged});

  @override
  State<LifestyleEmergencyForm> createState() => _LifestyleEmergencyFormState();
}

class _LifestyleEmergencyFormState extends State<LifestyleEmergencyForm> {
  late Lifestyle _l;
  late EmergencyContact _e;
  late final TextEditingController _occupation;
  late final TextEditingController _about;
  late final TextEditingController _ecName;
  late final TextEditingController _ecRel;
  late final TextEditingController _ecPhone;

  @override
  void initState() {
    super.initState();
    _l = widget.lifestyle?.copy() ?? Lifestyle();
    _e = widget.emergency?.copy() ?? EmergencyContact();
    _occupation = TextEditingController(text: _l.occupation)..addListener(_pushText);
    _about = TextEditingController(text: _l.about)..addListener(_pushText);
    _ecName = TextEditingController(text: _e.name)..addListener(_pushText);
    _ecRel = TextEditingController(text: _e.relationship)..addListener(_pushText);
    _ecPhone = TextEditingController(text: _e.phone)..addListener(_pushText);
  }

  @override
  void dispose() {
    _occupation.dispose();
    _about.dispose();
    _ecName.dispose();
    _ecRel.dispose();
    _ecPhone.dispose();
    super.dispose();
  }

  void _pushText() {
    _l.occupation = _occupation.text;
    _l.about = _about.text;
    _e.name = _ecName.text;
    _e.relationship = _ecRel.text;
    _e.phone = _ecPhone.text;
    widget.onChanged(_l.copy(), _e.copy());
  }

  void _push() => widget.onChanged(_l.copy(), _e.copy());

  Widget _segment(String label, List<(String, String)> options, String value, ValueChanged<String> onPick) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      Segment<String>(
        options: [for (final o in options) o.$1],
        value: value.isEmpty ? options.first.$1 : value,
        labelFor: (v) => labelFor(options, v),
        onChanged: (v) {
          onPick(v);
          setState(() {});
          _push();
        },
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _dropdown(String label, List<(String, String)> options, String value, ValueChanged<String> onPick) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      DropdownButtonFormField<String>(
        initialValue: value.isEmpty ? null : value,
        hint: const Text('Select…'),
        items: [for (final o in options) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
        onChanged: (v) {
          if (v == null) return;
          onPick(v);
          setState(() {});
          _push();
        },
      ),
      const SizedBox(height: 12),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Lifestyle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const Padding(
        padding: EdgeInsets.only(top: 2, bottom: 10),
        child: Text('Helps housemates know if you’ll be a good fit. Shared when you apply to a room.',
            style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
      ),
      _segment('Smoking', smokingOptions, _l.smoking, (v) => _l.smoking = v),
      _segment('Alcohol', alcoholOptions, _l.alcohol, (v) => _l.alcohol = v),
      _dropdown('Relationship status', relationshipOptions, _l.relationship, (v) => _l.relationship = v),
      _segment('Pets', petsOptions, _l.pets, (v) => _l.pets = v),
      _segment('Daily rhythm', scheduleOptions, _l.schedule, (v) => _l.schedule = v),
      _segment('Overnight guests', guestsOptions, _l.guests, (v) => _l.guests = v),
      _dropdown('Diet', dietOptions, _l.diet, (v) => _l.diet = v),
      const FieldLabel('Occupation'),
      TextField(controller: _occupation, decoration: const InputDecoration(hintText: 'e.g. Nurse, student, engineer')),
      const SizedBox(height: 12),
      const FieldLabel('About you (optional)'),
      TextField(controller: _about, maxLines: 3, decoration: const InputDecoration(hintText: 'A line or two about yourself…')),
      const SizedBox(height: 18),
      const Text('Emergency contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const Padding(
        padding: EdgeInsets.only(top: 2, bottom: 10),
        child: Text('Someone we can reach in an emergency.', style: TextStyle(color: HomiesColors.textDim, fontSize: 12)),
      ),
      const FieldLabel('Name'),
      TextField(controller: _ecName, decoration: const InputDecoration(hintText: 'Full name')),
      const SizedBox(height: 12),
      const FieldLabel('Relationship'),
      TextField(controller: _ecRel, decoration: const InputDecoration(hintText: 'e.g. Parent, sibling, partner')),
      const SizedBox(height: 12),
      const FieldLabel('Phone'),
      TextField(controller: _ecPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+61 4XX XXX XXX')),
    ]);
  }
}

/// Read-only summary of someone's lifestyle answers + emergency contact, used
/// where a leaseholder reviews an applicant.
class LifestyleSummary extends StatelessWidget {
  final Lifestyle? lifestyle;
  final EmergencyContact? emergency;
  // When true, the person has an emergency contact but has chosen to keep it
  // hidden — show a "Private" placeholder instead of the details.
  final bool emergencyPrivate;
  const LifestyleSummary({super.key, this.lifestyle, this.emergency, this.emergencyPrivate = false});

  @override
  Widget build(BuildContext context) {
    final l = lifestyle;
    final rows = <(String, String)>[
      if (l != null && l.smoking.isNotEmpty) ('Smoking', labelFor(smokingOptions, l.smoking)),
      if (l != null && l.alcohol.isNotEmpty) ('Alcohol', labelFor(alcoholOptions, l.alcohol)),
      if (l != null && l.relationship.isNotEmpty) ('Relationship', labelFor(relationshipOptions, l.relationship)),
      if (l != null && l.pets.isNotEmpty) ('Pets', labelFor(petsOptions, l.pets)),
      if (l != null && l.schedule.isNotEmpty) ('Daily rhythm', labelFor(scheduleOptions, l.schedule)),
      if (l != null && l.guests.isNotEmpty) ('Guests', labelFor(guestsOptions, l.guests)),
      if (l != null && l.diet.isNotEmpty) ('Diet', labelFor(dietOptions, l.diet)),
      if (l != null && l.occupation.isNotEmpty) ('Occupation', l.occupation),
    ];
    final e = emergency;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(r.$1, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim)),
            Flexible(child: Text(r.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
          ]),
        ),
      if (l != null && l.about.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('“${l.about}”', style: const TextStyle(fontSize: 12, color: HomiesColors.text, height: 1.35)),
        ),
      if (e != null && e.isComplete) ...[
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: HomiesColors.border)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Emergency contact', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          Flexible(
            child: Text('${e.name}${e.relationship.isNotEmpty ? ' (${e.relationship})' : ''} · ${e.phone}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          ),
        ]),
      ] else if (emergencyPrivate) ...[
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: HomiesColors.border)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Emergency contact', style: TextStyle(fontSize: 12, color: HomiesColors.textDim)),
          Row(children: const [
            Icon(Icons.lock_outline, size: 13, color: HomiesColors.textFaint),
            SizedBox(width: 4),
            Text('Private', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomiesColors.textFaint)),
          ]),
        ]),
      ],
    ]);
  }
}
