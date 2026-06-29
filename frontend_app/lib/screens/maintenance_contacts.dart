import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

const _categories = ['emergency', 'property', 'utilities', 'trades', 'other'];

const _categoryLabels = {
  'emergency': 'Emergency',
  'property': 'Property',
  'utilities': 'Utilities',
  'trades': 'Trades',
  'other': 'Other',
};

const _categoryIcons = {
  'emergency': Icons.emergency_outlined,
  'property': Icons.home_outlined,
  'utilities': Icons.bolt_outlined,
  'trades': Icons.build_outlined,
  'other': Icons.contacts_outlined,
};

const _categoryTones = {
  'emergency': ChipTone.danger,
  'property': ChipTone.accent,
  'utilities': ChipTone.warn,
  'trades': ChipTone.ok,
  'other': ChipTone.neutral,
};

class MaintenanceContactsScreen extends StatelessWidget {
  const MaintenanceContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final contacts = state.maintenanceContacts;

    // Group by category in the defined order
    final grouped = <String, List<MaintenanceContact>>{
      for (final cat in _categories)
        if (contacts.any((c) => c.category == cat))
          cat: contacts.where((c) => c.category == cat).toList(),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Maintenance contacts',
            subtitle: 'Emergency services, trades, utilities and property management.',
            action: isLeaseholder
                ? ElevatedButton.icon(
                    onPressed: () => _openSheet(context, state, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add contact'),
                  )
                : null,
          ),

          if (contacts.isEmpty)
            const EmptyState(title: 'No contacts yet'),

          for (final cat in grouped.keys) ...[
            _CategoryHeader(category: cat),
            for (final c in grouped[cat]!)
              _ContactCard(
                contact: c,
                isLeaseholder: isLeaseholder,
                onEdit: () => _openSheet(context, state, c),
                onDelete: () => _confirmDelete(context, state, c),
              ),
          ],

          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _openSheet(BuildContext context, HomiesState state, MaintenanceContact? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactSheet(existing: existing, state: state),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, HomiesState state, MaintenanceContact c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('Delete "${c.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: HomiesColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      state.mutate(() => state.maintenanceContacts.removeWhere((x) => x.id == c.id));
    }
  }
}

// ── Category header ───────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String category;
  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcons[category] ?? Icons.contacts_outlined;
    final label = _categoryLabels[category] ?? category;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: HomiesColors.textDim),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: HomiesColors.textFaint,
                letterSpacing: 0.8)),
      ]),
    );
  }
}

// ── Contact card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final MaintenanceContact contact;
  final bool isLeaseholder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.isLeaseholder,
    required this.onEdit,
    required this.onDelete,
  });

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = _categoryTones[contact.category] ?? ChipTone.neutral;

    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header row: name + edit/delete
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(contact.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              HomiesChip(_categoryLabels[contact.category] ?? contact.category,
                  tone: tone),
            ]),
          ),
          if (isLeaseholder) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 17, color: HomiesColors.textDim),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 17, color: HomiesColors.textDim),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
            ),
          ],
        ]),

        // Phone
        if (contact.phone != null && contact.phone!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ContactRow(
            icon: Icons.phone_outlined,
            value: contact.phone!,
            onTap: () => _copy(context, contact.phone!, 'Phone number'),
          ),
        ],

        // Email
        if (contact.email != null && contact.email!.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ContactRow(
            icon: Icons.email_outlined,
            value: contact.email!,
            onTap: () => _copy(context, contact.email!, 'Email address'),
          ),
        ],

        // Notes
        if (contact.notes != null && contact.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(contact.notes!,
              style: const TextStyle(
                  fontSize: 12, color: HomiesColors.textDim, height: 1.5)),
        ],
      ]),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 15, color: HomiesColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: HomiesColors.accent,
                    fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.copy_outlined, size: 13, color: HomiesColors.textFaint),
        ]),
      ),
    );
  }
}

// ── Contact editor sheet ──────────────────────────────────────────────────────

class _ContactSheet extends StatefulWidget {
  final MaintenanceContact? existing;
  final HomiesState state;
  const _ContactSheet({required this.existing, required this.state});

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _notesCtrl;
  late String _category;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? 'other';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  void _save() {
    final state = widget.state;
    final cu = state.currentUser!;
    if (widget.existing != null) {
      state.mutate(() {
        widget.existing!.name = _nameCtrl.text.trim();
        widget.existing!.category = _category;
        widget.existing!.phone =
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
        widget.existing!.email =
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
        widget.existing!.notes =
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();
      });
    } else {
      state.mutate(() {
        state.maintenanceContacts.add(MaintenanceContact(
          id: 'mc-${Random().nextInt(0xFFFF).toRadixString(36)}',
          name: _nameCtrl.text.trim(),
          category: _category,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          addedBy: cu.id,
          addedAt: DateTime.now().toIso8601String(),
        ));
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(isEdit ? 'Edit contact' : 'Add contact',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ]),
          const SizedBox(height: 12),
          const FieldLabel('Name'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'e.g. Jake\'s Plumbing'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Category'),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: [
              for (final cat in _categories)
                DropdownMenuItem(
                  value: cat,
                  child: Row(children: [
                    Icon(_categoryIcons[cat], size: 16, color: HomiesColors.textDim),
                    const SizedBox(width: 8),
                    Text(_categoryLabels[cat] ?? cat),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'other'),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Phone'),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '0400 000 000'),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Email'),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'contact@example.com'),
          ),
          const SizedBox(height: 10),
          const FieldLabel('Notes (optional)'),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Hours, account numbers, tips…'),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _canSave ? _save : null,
              child: Text(isEdit ? 'Save changes' : 'Add contact'),
            ),
          ]),
        ],
      ),
    );
  }
}
