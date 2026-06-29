import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  late HouseTerms _t;
  bool _dirty = false;
  final _customCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dirty) {
      _t = _copyTerms(HomiesScope.of(context).houseTerms);
      _customCtrl.text = _t.customClauses ?? '';
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  HouseTerms _copyTerms(HouseTerms src) => HouseTerms(
        minStayMonths: src.minStayMonths,
        earlyLeaveBondPct: src.earlyLeaveBondPct,
        midLeaveBondPct: src.midLeaveBondPct,
        lateLeaveBondPct: src.lateLeaveBondPct,
        noticePeriodDays: src.noticePeriodDays,
        lateRentGraceDays: src.lateRentGraceDays,
        lateRentFeePerDay: src.lateRentFeePerDay,
        petsAllowed: src.petsAllowed,
        maxGuestNightsPerWeek: src.maxGuestNightsPerWeek,
        quietHoursStart: src.quietHoursStart,
        quietHoursEnd: src.quietHoursEnd,
        smokingAllowed: src.smokingAllowed,
        sublettingAllowed: src.sublettingAllowed,
        customClauses: src.customClauses,
      );

  void _mark(void Function() fn) => setState(() { fn(); _dirty = true; });

  void _save(HomiesState state) {
    _t.customClauses = _customCtrl.text.trim().isEmpty ? null : _customCtrl.text.trim();
    state.mutate(() {
      final h = state.houseTerms;
      h.minStayMonths = _t.minStayMonths;
      h.earlyLeaveBondPct = _t.earlyLeaveBondPct;
      h.midLeaveBondPct = _t.midLeaveBondPct;
      h.lateLeaveBondPct = _t.lateLeaveBondPct;
      h.noticePeriodDays = _t.noticePeriodDays;
      h.lateRentGraceDays = _t.lateRentGraceDays;
      h.lateRentFeePerDay = _t.lateRentFeePerDay;
      h.petsAllowed = _t.petsAllowed;
      h.maxGuestNightsPerWeek = _t.maxGuestNightsPerWeek;
      h.quietHoursStart = _t.quietHoursStart;
      h.quietHoursEnd = _t.quietHoursEnd;
      h.smokingAllowed = _t.smokingAllowed;
      h.sublettingAllowed = _t.sublettingAllowed;
      h.customClauses = _t.customClauses;
    });
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms saved.'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final parts = (isStart ? _t.quietHoursStart : _t.quietHoursEnd).split(':');
    final h = int.tryParse(parts[0]) ?? 22;
    final m = int.tryParse(parts[1]) ?? 0;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m));
    if (picked == null) return;
    final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _mark(() { if (isStart) { _t.quietHoursStart = str; } else { _t.quietHoursEnd = str; } });
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isLeaseholder = state.currentUser?.role == 'leaseholder';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHead(
              title: 'Terms & conditions',
              subtitle: isLeaseholder
                  ? 'Set the house rules and policies. Tenants can view these at any time.'
                  : 'House policies set by your leaseholder.',
            ),

            if (!isLeaseholder)
              const InfoBanner(
                icon: Icons.info_outline,
                text: 'These terms were set by your leaseholder and are part of your tenancy arrangement.',
              ),

            // ── Bond & departure ────────────────────────────────────────────
            _SectionCard(
              icon: Icons.shield_outlined,
              iconColor: HomiesColors.warn,
              title: 'Bond & early departure',
              subtitle: 'How much bond is retained when a tenant leaves.',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isLeaseholder) ...[
                  const FieldLabel('Minimum stay'),
                  const SizedBox(height: 6),
                  _Stepper(
                    value: _t.minStayMonths,
                    min: 1,
                    max: 12,
                    label: (v) => '$v month${v == 1 ? '' : 's'}',
                    onChanged: (v) => _mark(() => _t.minStayMonths = v),
                  ),
                  const SizedBox(height: 16),
                ] else
                  _ReadRow(label: 'Minimum stay', value: '${_t.minStayMonths} month${_t.minStayMonths == 1 ? '' : 's'}'),

                const SizedBox(height: 4),
                _BondTable(t: _t, isLeaseholder: isLeaseholder, onChanged: _mark),
                const SizedBox(height: 8),
                const Text(
                  'Bond deductions are calculated as a percentage of the total bond amount paid at the start of the tenancy.',
                  style: TextStyle(fontSize: 11, color: HomiesColors.textFaint, height: 1.4),
                ),
              ]),
            ),

            // ── Notice period ───────────────────────────────────────────────
            _SectionCard(
              icon: Icons.event_note_outlined,
              iconColor: HomiesColors.accent,
              title: 'Notice period',
              subtitle: 'Written notice required before vacating.',
              child: isLeaseholder
                  ? _Stepper(
                      value: _t.noticePeriodDays,
                      min: 7,
                      max: 90,
                      step: 7,
                      label: (v) => '$v days',
                      onChanged: (v) => _mark(() => _t.noticePeriodDays = v),
                    )
                  : _ReadRow(label: 'Notice required', value: '${_t.noticePeriodDays} days'),
            ),

            // ── Late rent ───────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF3182CE),
              title: 'Late rent policy',
              subtitle: 'Grace period and fees applied to overdue rent.',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isLeaseholder) ...[
                  const FieldLabel('Grace period (days before late fee applies)'),
                  const SizedBox(height: 6),
                  _Stepper(
                    value: _t.lateRentGraceDays,
                    min: 0,
                    max: 14,
                    label: (v) => v == 0 ? 'No grace' : '$v day${v == 1 ? '' : 's'}',
                    onChanged: (v) => _mark(() => _t.lateRentGraceDays = v),
                  ),
                  const SizedBox(height: 16),
                  const FieldLabel('Daily late fee (AUD per day)'),
                  const SizedBox(height: 6),
                  _DollarStepper(
                    value: _t.lateRentFeePerDay,
                    onChanged: (v) => _mark(() => _t.lateRentFeePerDay = v),
                  ),
                ] else ...[
                  _ReadRow(
                    label: 'Grace period',
                    value: _t.lateRentGraceDays == 0 ? 'None — fees apply immediately' : '${_t.lateRentGraceDays} day${_t.lateRentGraceDays == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 8),
                  _ReadRow(
                    label: 'Daily late fee',
                    value: _t.lateRentFeePerDay == 0 ? 'No fee set' : '\$${_t.lateRentFeePerDay.toStringAsFixed(2)}/day',
                  ),
                ],
              ]),
            ),

            // ── Guests ──────────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.people_outline,
              iconColor: const Color(0xFF805AD5),
              title: 'Guest policy',
              subtitle: 'Overnight guest limits per week.',
              child: isLeaseholder
                  ? _Stepper(
                      value: _t.maxGuestNightsPerWeek,
                      min: 0,
                      max: 7,
                      label: (v) => v == 0 ? 'No overnight guests' : '$v night${v == 1 ? '' : 's'}/week',
                      onChanged: (v) => _mark(() => _t.maxGuestNightsPerWeek = v),
                    )
                  : _ReadRow(
                      label: 'Max overnight guests',
                      value: _t.maxGuestNightsPerWeek == 0
                          ? 'Not permitted'
                          : '${_t.maxGuestNightsPerWeek} night${_t.maxGuestNightsPerWeek == 1 ? '' : 's'} per week',
                    ),
            ),

            // ── Quiet hours ─────────────────────────────────────────────────
            _SectionCard(
              icon: Icons.nightlight_outlined,
              iconColor: const Color(0xFF2C7A7B),
              title: 'Quiet hours',
              subtitle: 'No loud music, parties or disturbances during these hours.',
              child: isLeaseholder
                  ? Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const FieldLabel('From'),
                          const SizedBox(height: 4),
                          _TimeButton(time: _t.quietHoursStart, onTap: () => _pickTime(true)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const FieldLabel('Until'),
                          const SizedBox(height: 4),
                          _TimeButton(time: _t.quietHoursEnd, onTap: () => _pickTime(false)),
                        ]),
                      ),
                    ])
                  : _ReadRow(
                      label: 'Quiet hours',
                      value: '${_fmtTime(_t.quietHoursStart)} – ${_fmtTime(_t.quietHoursEnd)}',
                    ),
            ),

            // ── House policies (toggles) ─────────────────────────────────────
            _SectionCard(
              icon: Icons.gavel_outlined,
              iconColor: HomiesColors.ok,
              title: 'House policies',
              subtitle: 'Permitted and prohibited activities.',
              child: Column(children: [
                _PolicyRow(
                  icon: Icons.pets_outlined,
                  label: 'Pets allowed',
                  value: _t.petsAllowed,
                  editable: isLeaseholder,
                  onChanged: (v) => _mark(() => _t.petsAllowed = v),
                ),
                const Divider(height: 1),
                _PolicyRow(
                  icon: Icons.smoking_rooms_outlined,
                  label: 'Smoking on premises',
                  value: _t.smokingAllowed,
                  editable: isLeaseholder,
                  onChanged: (v) => _mark(() => _t.smokingAllowed = v),
                ),
                const Divider(height: 1),
                _PolicyRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Subletting allowed',
                  value: _t.sublettingAllowed,
                  editable: isLeaseholder,
                  onChanged: (v) => _mark(() => _t.sublettingAllowed = v),
                ),
              ]),
            ),

            // ── Standard clauses (fixed, informational) ─────────────────────
            _SectionCard(
              icon: Icons.article_outlined,
              iconColor: HomiesColors.textDim,
              title: 'Standard clauses',
              subtitle: 'These apply to all tenancies by default.',
              child: Column(children: [
                _ClauseItem(
                  title: 'Property condition',
                  body: 'Tenants are responsible for damage beyond fair wear and tear. A condition report will be used as reference on departure.',
                ),
                _ClauseItem(
                  title: 'Inspections',
                  body: 'The leaseholder may conduct reasonable property inspections with at least 24 hours\' written notice.',
                ),
                _ClauseItem(
                  title: 'Rent payments',
                  body: 'Rent must be paid in full on the agreed due date. Partial payments are not accepted without prior written agreement.',
                ),
                _ClauseItem(
                  title: 'Common areas',
                  body: 'All tenants share equal responsibility for keeping common areas clean and in good condition.',
                ),
                _ClauseItem(
                  title: 'Utilities',
                  body: 'Tenants must use utilities reasonably. Excessive or wasteful usage may be charged back to the responsible tenant.',
                ),
                _ClauseItem(
                  title: 'Dispute resolution',
                  body: 'Disputes should first be raised with the leaseholder in writing. If unresolved, either party may contact the relevant state tenancy authority.',
                ),
                _ClauseItem(
                  title: 'Breach of terms',
                  body: 'Repeated or serious breaches of these terms may result in early termination of tenancy in accordance with applicable tenancy laws.',
                  isLast: true,
                ),
              ]),
            ),

            // ── Custom clauses ───────────────────────────────────────────────
            if (isLeaseholder || (_t.customClauses != null && _t.customClauses!.isNotEmpty))
              _SectionCard(
                icon: Icons.edit_note_outlined,
                iconColor: HomiesColors.accent,
                title: 'Additional terms',
                subtitle: isLeaseholder
                    ? 'Any extra clauses specific to this property or arrangement.'
                    : 'Extra terms added by your leaseholder.',
                child: isLeaseholder
                    ? TextField(
                        controller: _customCtrl,
                        maxLines: 5,
                        onChanged: (_) => setState(() => _dirty = true),
                        decoration: const InputDecoration(
                          hintText: 'e.g. No parties without 48 hours notice, BBQ cleaned after each use…',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                        style: const TextStyle(fontSize: 13, color: HomiesColors.text, height: 1.5),
                      )
                    : Text(
                        _t.customClauses ?? '',
                        style: const TextStyle(fontSize: 13, color: HomiesColors.text, height: 1.6),
                      ),
              ),

            if (isLeaseholder && _dirty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _save(state),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiesColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save terms', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final suffix = h < 12 ? 'am' : 'pm';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }
}

// ─── Bond table ───────────────────────────────────────────────────────────────

class _BondTable extends StatelessWidget {
  final HouseTerms t;
  final bool isLeaseholder;
  final void Function(void Function()) onChanged;
  const _BondTable({required this.t, required this.isLeaseholder, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final mid = t.minStayMonths;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        _BondRow(
          label: 'Before $mid month${mid == 1 ? '' : 's'}',
          sublabel: 'Early departure',
          pct: t.earlyLeaveBondPct,
          isLeaseholder: isLeaseholder,
          color: HomiesColors.danger,
          min: 0, max: 100,
          onChanged: (v) => onChanged(() => t.earlyLeaveBondPct = v),
          isFirst: true,
        ),
        const Divider(height: 1),
        _BondRow(
          label: '$mid – 6 months',
          sublabel: 'Standard departure',
          pct: t.midLeaveBondPct,
          isLeaseholder: isLeaseholder,
          color: HomiesColors.warn,
          min: 0, max: 100,
          onChanged: (v) => onChanged(() => t.midLeaveBondPct = v),
        ),
        const Divider(height: 1),
        _BondRow(
          label: '6+ months',
          sublabel: 'Long-term departure',
          pct: t.lateLeaveBondPct,
          isLeaseholder: isLeaseholder,
          color: HomiesColors.ok,
          min: 0, max: 100,
          onChanged: (v) => onChanged(() => t.lateLeaveBondPct = v),
          isLast: true,
        ),
      ]),
    );
  }
}

class _BondRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final int pct;
  final bool isLeaseholder;
  final Color color;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool isFirst;
  final bool isLast;
  const _BondRow({
    required this.label, required this.sublabel, required this.pct,
    required this.isLeaseholder, required this.color,
    required this.min, required this.max, required this.onChanged,
    this.isFirst = false, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomiesColors.text)),
            Text(sublabel, style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint)),
          ]),
        ),
        if (isLeaseholder)
          Row(children: [
            _SmallBtn(icon: Icons.remove, onTap: pct > min ? () => onChanged(pct - 5) : null),
            const SizedBox(width: 6),
            Container(
              width: 46,
              alignment: Alignment.center,
              child: Text(
                '$pct%',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(width: 6),
            _SmallBtn(icon: Icons.add, onTap: pct < max ? () => onChanged(pct + 5) : null),
          ])
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$pct% bond', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
      ]),
    );
  }
}

// ─── Generic stepper ─────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.value, required this.min, required this.max,
    this.step = 1, required this.label, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _SmallBtn(icon: Icons.remove, onTap: value > min ? () => onChanged(value - step) : null),
      const SizedBox(width: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 100),
        child: Text(
          label(value),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text),
        ),
      ),
      const SizedBox(width: 10),
      _SmallBtn(icon: Icons.add, onTap: value < max ? () => onChanged(value + step) : null),
    ]);
  }
}

// ─── Dollar stepper ──────────────────────────────────────────────────────────

class _DollarStepper extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _DollarStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _SmallBtn(icon: Icons.remove, onTap: value >= 5 ? () => onChanged(value - 5) : null),
      const SizedBox(width: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 80),
        child: Text(
          value == 0 ? 'No fee' : '\$${value.toStringAsFixed(0)}/day',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text),
        ),
      ),
      const SizedBox(width: 10),
      _SmallBtn(icon: Icons.add, onTap: () => onChanged(value + 5)),
    ]);
  }
}

// ─── Small +/- button ────────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SmallBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: enabled ? HomiesColors.surface2 : HomiesColors.border,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HomiesColors.border),
        ),
        child: Icon(icon, size: 16, color: enabled ? HomiesColors.text : HomiesColors.textFaint),
      ),
    );
  }
}

// ─── Policy toggle row ───────────────────────────────────────────────────────

class _PolicyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final bool editable;
  final ValueChanged<bool> onChanged;
  const _PolicyRow({required this.icon, required this.label, required this.value, required this.editable, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: HomiesColors.textDim),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: HomiesColors.text))),
        if (editable)
          Switch(value: value, onChanged: onChanged, activeThumbColor: HomiesColors.accent)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: value ? HomiesColors.okSoft : HomiesColors.dangerSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value ? 'Allowed' : 'Not allowed',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: value ? HomiesColors.ok : HomiesColors.danger,
              ),
            ),
          ),
      ]),
    );
  }
}

// ─── Time button ─────────────────────────────────────────────────────────────

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;
  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final suffix = h < 12 ? 'am' : 'pm';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final display = '$h12:${m.toString().padLeft(2, '0')} $suffix';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: HomiesColors.surface2,
          border: Border.all(color: HomiesColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.access_time_outlined, size: 16, color: HomiesColors.textDim),
          const SizedBox(width: 6),
          Text(display, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomiesColors.text)),
        ]),
      ),
    );
  }
}

// ─── Read-only row ───────────────────────────────────────────────────────────

class _ReadRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReadRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 2,
        child: Text(label, style: const TextStyle(fontSize: 13, color: HomiesColors.textDim)),
      ),
      Expanded(
        flex: 3,
        child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomiesColors.text)),
      ),
    ]);
  }
}

// ─── Standard clause item ────────────────────────────────────────────────────

class _ClauseItem extends StatelessWidget {
  final String title;
  final String body;
  final bool isLast;
  const _ClauseItem({required this.title, required this.body, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HomiesColors.text)),
        const SizedBox(height: 3),
        Text(body, style: const TextStyle(fontSize: 12, color: HomiesColors.textDim, height: 1.5)),
      ]),
    );
  }
}

// ─── Section card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HomiesColors.surface,
        border: Border.all(color: HomiesColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomiesColors.text)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint, height: 1.3)),
            ])),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}
