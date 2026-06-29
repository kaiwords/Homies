import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

// ─── Category metadata ────────────────────────────────────────────────────────

IconData _catIcon(String cat) {
  switch (cat) {
    case 'rent':         return Icons.home_outlined;
    case 'bill':         return Icons.receipt_long_outlined;
    case 'subscription': return Icons.subscriptions_outlined;
    case 'grocery':      return Icons.shopping_cart_outlined;
    case 'necessity':    return Icons.cleaning_services_outlined;
    case 'eating_out':   return Icons.restaurant_outlined;
    case 'going_out':    return Icons.local_activity_outlined;
    case 'clothing':     return Icons.checkroom_outlined;
    case 'transport':    return Icons.directions_car_outlined;
    case 'health':       return Icons.local_hospital_outlined;
    case 'personal_care':return Icons.face_outlined;
    case 'fitness':      return Icons.fitness_center_outlined;
    case 'gifts':        return Icons.card_giftcard_outlined;
    case 'travel':       return Icons.flight_outlined;
    case 'college_fee':  return Icons.school_outlined;
    case 'mobile_plan':  return Icons.sim_card_outlined;
    case 'home':         return Icons.chair_outlined;
    case 'entertainment':return Icons.movie_outlined;
    default:             return Icons.wallet_outlined;
  }
}

Color _catColor(String cat) {
  switch (cat) {
    case 'rent':          return HomiesColors.accent;
    case 'bill':          return const Color(0xFF3182CE);
    case 'subscription':  return const Color(0xFF805AD5);
    case 'grocery':       return HomiesColors.ok;
    case 'necessity':     return HomiesColors.warn;
    case 'eating_out':    return const Color(0xFFDD6B20);
    case 'going_out':     return const Color(0xFF00897B);
    case 'clothing':      return const Color(0xFFD53F8C);
    case 'transport':     return const Color(0xFF2B6CB0);
    case 'health':        return const Color(0xFFC53030);
    case 'personal_care': return const Color(0xFF97266D);
    case 'fitness':       return const Color(0xFF276749);
    case 'gifts':         return const Color(0xFFB7791F);
    case 'travel':        return const Color(0xFF0987A0);
    case 'college_fee':   return const Color(0xFF2C7A7B);
    case 'mobile_plan':   return const Color(0xFF6B46C1);
    case 'home':          return const Color(0xFF744210);
    case 'entertainment': return const Color(0xFF553C9A);
    default:              return HomiesColors.textDim;
  }
}

String _catLabel(String cat) {
  switch (cat) {
    case 'rent':          return 'Rent';
    case 'bill':          return 'Bills';
    case 'subscription':  return 'Subscriptions';
    case 'grocery':       return 'Groceries';
    case 'necessity':     return 'Necessities';
    case 'eating_out':    return 'Eating out';
    case 'going_out':     return 'Going out';
    case 'clothing':      return 'Clothing';
    case 'transport':     return 'Transport';
    case 'health':        return 'Health';
    case 'personal_care': return 'Personal care';
    case 'fitness':       return 'Fitness';
    case 'gifts':         return 'Gifts';
    case 'travel':        return 'Travel';
    case 'college_fee':   return 'College fee';
    case 'mobile_plan':   return 'Mobile plan';
    case 'home':          return 'Home & garden';
    case 'entertainment': return 'Entertainment';
    default:              return 'Other';
  }
}

// Manual-entry categories the user can pick from
const _addCategories = [
  ('grocery',       'Groceries'),
  ('eating_out',    'Eating out'),
  ('going_out',     'Going out'),
  ('clothing',      'Clothing'),
  ('transport',     'Transport'),
  ('subscription',  'Subscription'),
  ('mobile_plan',   'Mobile plan'),
  ('entertainment', 'Entertainment'),
  ('health',        'Health'),
  ('personal_care', 'Personal care'),
  ('fitness',       'Fitness'),
  ('college_fee',   'College fee'),
  ('gifts',         'Gifts'),
  ('travel',        'Travel'),
  ('home',          'Home & garden'),
  ('necessity',     'Household item'),
  ('other',         'Other'),
];

// ─── Period ───────────────────────────────────────────────────────────────────

enum _Period { week, month, year, allTime }

String _periodLabel(_Period p) {
  switch (p) {
    case _Period.week:
      return 'This Week';
    case _Period.month:
      return 'This Month';
    case _Period.year:
      return 'This Year';
    case _Period.allTime:
      return 'All Time';
  }
}

// ─── Transaction entry ────────────────────────────────────────────────────────

class _Entry {
  final String category;
  final String title;
  final double amount;
  final DateTime date;
  final String? personalId; // non-null → user can delete it

  const _Entry({
    required this.category,
    required this.title,
    required this.amount,
    required this.date,
    this.personalId,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MySpendingScreen extends StatefulWidget {
  const MySpendingScreen({super.key});

  @override
  State<MySpendingScreen> createState() => _MySpendingScreenState();
}

class _MySpendingScreenState extends State<MySpendingScreen> {
  _Period _period = _Period.month;

  // ── Date range ──────────────────────────────────────────────────────────────

  (DateTime, DateTime) get _range {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        return (start, start.add(const Duration(days: 6)));
      case _Period.month:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
      case _Period.year:
        return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31));
      case _Period.allTime:
        return (DateTime(2000), DateTime(2100));
    }
  }

  bool _inRange(String? iso) {
    final d = parseIso(iso);
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    final (start, end) = _range;
    return !day.isBefore(start) && !day.isAfter(end);
  }

  // ── Cadence helpers ─────────────────────────────────────────────────────────

  double _cadenceDays(String cadence) {
    switch (cadence) {
      case 'weekly':
        return 7.0;
      case 'fortnightly':
        return 14.0;
      case 'monthly':
        return 30.44;
      case 'quarterly':
        return 91.31;
      case 'half-yearly':
        return 182.62;
      case 'yearly':
        return 365.25;
      default:
        return 30.44;
    }
  }

  /// How much of a per-cadence amount falls within the selected period,
  /// capped at the effective overlap between the period and [activeFrom].
  double _amountForPeriod(double perCadence, String cadence, String? activeFromIso) {
    final (start, end) = _range;
    final now = DateTime.now();
    final activeFrom = parseIso(activeFromIso) ?? start;
    final effectiveStart = activeFrom.isAfter(start) ? activeFrom : start;
    final effectiveEnd = end.isAfter(now) ? now : end;
    if (effectiveEnd.isBefore(effectiveStart)) return 0;
    final days = effectiveEnd.difference(effectiveStart).inDays + 1;
    return perCadence * (days / _cadenceDays(cadence));
  }

  // ── Build transaction list ──────────────────────────────────────────────────

  List<_Entry> _buildEntries(HomiesState state) {
    final uid = state.currentUser!.id;
    final entries = <_Entry>[];
    final (periodStart, _) = _range;

    // 1. Rent — only actual RentPayment records (created when user marks rent paid)
    for (final p in state.rentPayments) {
      if (p.userId != uid) continue;
      if (!_inRange(p.paidAt)) continue;
      entries.add(_Entry(
        category: 'rent',
        title: 'Rent — ${cadenceLabel(state.property.rentCadence).toLowerCase()} share',
        amount: p.amount,
        date: parseIso(p.paidAt) ?? periodStart,
      ));
    }

    // 2. Bills — only when this user's share is marked as paid; use payment date
    for (final b in state.bills) {
      if (b.paidBy[uid] != true) continue;
      final share = b.shares[uid] ?? 0;
      if (share <= 0) continue;
      final pay = b.payments[uid];
      final dateStr = pay?.at ?? b.dueDate;
      if (!_inRange(dateStr)) continue;
      entries.add(_Entry(
        category: 'bill',
        title: b.title,
        amount: share,
        date: parseIso(dateStr) ?? periodStart,
      ));
    }

    // 3. Subscriptions
    //    Payer: fronts the money continuously — pro-rate their own share.
    //    Others: only show once they mark their reimbursement as paid; use payment date.
    for (final s in state.subscriptions) {
      if (!s.participants.contains(uid)) continue;
      final share = s.shares[uid] ?? 0;
      if (share <= 0) continue;
      if (s.payer == uid) {
        final amount = _amountForPeriod(share, s.cadence, null);
        if (amount > 0.01) {
          entries.add(_Entry(category: 'subscription', title: s.name, amount: amount, date: periodStart));
        }
      } else {
        if (s.paidBy[uid] != true) continue;
        final pay = s.payments[uid];
        final dateStr = pay?.at;
        if (dateStr == null || !_inRange(dateStr)) continue;
        entries.add(_Entry(
          category: 'subscription',
          title: s.name,
          amount: share,
          date: parseIso(dateStr) ?? periodStart,
        ));
      }
    }

    // 4. Groceries
    //    Shared + payer: user already spent it — show their share from purchase date.
    //    Shared + participant: show only once they mark their reimbursement as paid.
    //    Individual: user is the sole buyer, show full amount from purchase date.
    for (final g in state.groceries) {
      if (g.mode == 'shared') {
        final share = g.shares[uid];
        if (share == null || share <= 0) continue;
        if (g.payer == uid) {
          if (!_inRange(g.date)) continue;
          entries.add(_Entry(category: 'grocery', title: g.title, amount: share, date: parseIso(g.date) ?? periodStart));
        } else {
          if (g.paidBy[uid] != true) continue;
          final pay = g.payments[uid];
          final dateStr = pay?.at ?? g.date;
          if (!_inRange(dateStr)) continue;
          entries.add(_Entry(category: 'grocery', title: g.title, amount: share, date: parseIso(dateStr) ?? periodStart));
        }
      } else if (g.mode == 'individual' && g.payer == uid) {
        if (!_inRange(g.date)) continue;
        entries.add(_Entry(category: 'grocery', title: g.title, amount: g.total, date: parseIso(g.date) ?? periodStart));
      }
    }

    // 5. Necessities — same pattern as groceries
    for (final n in state.necessities) {
      if (n.mode == 'shared') {
        final share = n.shares[uid];
        if (share == null || share <= 0) continue;
        if (n.payer == uid) {
          if (!_inRange(n.date)) continue;
          entries.add(_Entry(category: 'necessity', title: n.item, amount: share, date: parseIso(n.date) ?? periodStart));
        } else {
          if (n.paidBy[uid] != true) continue;
          final pay = n.payments[uid];
          final dateStr = pay?.at ?? n.date;
          if (!_inRange(dateStr)) continue;
          entries.add(_Entry(category: 'necessity', title: n.item, amount: share, date: parseIso(dateStr) ?? periodStart));
        }
      } else if (n.mode == 'individual' && n.payer == uid) {
        if (!_inRange(n.date)) continue;
        entries.add(_Entry(category: 'necessity', title: n.item, amount: n.amount, date: parseIso(n.date) ?? periodStart));
      }
    }

    // 6. Personal expenses (manually logged)
    for (final p in state.personalExpenses) {
      if (p.userId != uid) continue;
      if (!_inRange(p.date)) continue;
      entries.add(_Entry(
        category: p.category,
        title: p.title,
        amount: p.amount,
        date: parseIso(p.date) ?? periodStart,
        personalId: p.id,
      ));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  // ── Period heading string ───────────────────────────────────────────────────

  String _rangeHeading() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:
        final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${fmtDateShort(start.toIso8601String())} – ${fmtDateShort(end.toIso8601String())}';
      case _Period.month:
        return '${_monthName(now.month)} ${now.year}';
      case _Period.year:
        return '${now.year}';
      case _Period.allTime:
        return 'Since you joined';
    }
  }

  String _monthName(int m) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return months[m];
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _delete(BuildContext context, HomiesState state, String id) {
    state.mutate(() => state.personalExpenses.removeWhere((p) => p.id == id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal expense removed')),
    );
  }

  Future<void> _add(BuildContext context, HomiesState state) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSheet(state: state),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final entries = _buildEntries(state);
    final total = entries.fold(0.0, (s, e) => s + e.amount);

    final byCategory = <String, double>{};
    for (final e in entries) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    return Stack(children: [
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHead(
              title: 'My Spending',
              subtitle: 'Your personal spending — rent, bills, subscriptions, groceries, eating out, going out, college fees and more.',
            ),

            // Period selector
            Segment<_Period>(
              options: _Period.values,
              value: _period,
              labelFor: _periodLabel,
              onChanged: (p) => setState(() => _period = p),
              optionPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            ),

            const SizedBox(height: 12),

            // Total summary card
            _TotalCard(total: total, heading: _rangeHeading()),

            // Category breakdown
            if (byCategory.isNotEmpty) ...[
              const SizedBox(height: 8),
              _CategoryBreakdown(totals: byCategory),
            ],

            const SizedBox(height: 16),

            // Transaction list header
            Row(children: [
              const Expanded(
                child: Text('Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (entries.isNotEmpty)
                Text('${entries.length}', style: const TextStyle(color: HomiesColors.textDim, fontSize: 13)),
            ]),

            const SizedBox(height: 6),

            if (entries.isEmpty)
              const EmptyState(title: 'No spending in this period')
            else
              for (final e in entries)
                _EntryRow(
                  entry: e,
                  onDelete: e.personalId != null
                      ? () => _delete(context, state, e.personalId!)
                      : null,
                ),
          ]),
        ),
      ),

      // FAB overlay
      Positioned(
        right: 16,
        bottom: 16,
        child: SafeArea(
          child: FloatingActionButton.extended(
            heroTag: 'mySpendingFab',
            onPressed: () => _add(context, state),
            icon: const Icon(Icons.add),
            label: const Text('Log expense'),
            backgroundColor: HomiesColors.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    ]);
  }
}

// ─── Total summary card ───────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  final String heading;
  const _TotalCard({required this.total, required this.heading});

  @override
  Widget build(BuildContext context) {
    return HomiesCard(
      color: HomiesColors.accent,
      borderColor: HomiesColors.accentStrong,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          heading,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          fmtAUD(total),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Total personal spending',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ]),
    );
  }
}

// ─── Category breakdown ───────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> totals;
  const _CategoryBreakdown({required this.totals});

  @override
  Widget build(BuildContext context) {
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in sorted)
          _CatChip(category: e.key, amount: e.value),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final String category;
  final double amount;
  const _CatChip({required this.category, required this.amount});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_catIcon(category), size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          '${_catLabel(category)}  ${fmtAUD(amount)}',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

// ─── Transaction row ──────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final _Entry entry;
  final VoidCallback? onDelete;
  const _EntryRow({required this.entry, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(entry.category);
    return HomiesCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(_catIcon(entry.category), size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_catLabel(entry.category),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 6),
              Text(fmtDateShort(entry.date.toIso8601String()),
                  style: const TextStyle(color: HomiesColors.textFaint, fontSize: 11)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Text(fmtAUD(entry.amount),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        if (onDelete != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 17, color: HomiesColors.textFaint),
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Remove this personal expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: HomiesColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) onDelete?.call();
  }
}

// ─── Add expense sheet ────────────────────────────────────────────────────────

class _AddSheet extends StatefulWidget {
  final HomiesState state;
  const _AddSheet({required this.state});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _category = 'grocery';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_amountCtrl.text.trim()) ?? 0) > 0;

  void _save() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    final uid = widget.state.currentUser?.id ?? '';
    final dateIso = _date.toIso8601String().substring(0, 10);
    widget.state.mutate(() {
      widget.state.personalExpenses.add(PersonalExpense(
        id: const Uuid().v4(),
        userId: uid,
        category: _category,
        title: _titleCtrl.text.trim(),
        amount: amount,
        date: dateIso,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense logged ✓')),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 28),
        child: ListView(controller: ctrl, children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: HomiesColors.textFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Log a personal expense',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Track your own spending — groceries, eating out, bills, college fees and more.',
              style: TextStyle(color: HomiesColors.textDim, fontSize: 13)),
          const SizedBox(height: 16),

          // Category
          const FieldLabel('Category'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (val, label) in _addCategories)
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 13)),
                  selected: _category == val,
                  onSelected: (_) => setState(() => _category = val),
                  selectedColor: HomiesColors.accentSoft,
                  checkmarkColor: HomiesColors.accentStrong,
                  side: BorderSide(
                    color: _category == val
                        ? HomiesColors.accentStrong.withValues(alpha: 0.5)
                        : HomiesColors.textFaint.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          const FieldLabel('Description'),
          TextField(
            controller: _titleCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'e.g. Woolworths personal shop'),
          ),
          const SizedBox(height: 12),

          // Amount
          const FieldLabel('Amount'),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00'),
          ),
          const SizedBox(height: 12),

          // Date
          const FieldLabel('Date'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: HomiesColors.surface,
                border: Border.all(color: HomiesColors.borderStrong),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: HomiesColors.textDim),
                const SizedBox(width: 8),
                Text(fmtDate(_date.toIso8601String()),
                    style: const TextStyle(fontSize: 14, color: HomiesColors.text)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Note (optional)
          const FieldLabel('Note (optional)'),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Monthly top-up'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _valid ? _save : null,
            child: const Text('Save expense'),
          ),
        ]),
      ),
    );
  }
}
