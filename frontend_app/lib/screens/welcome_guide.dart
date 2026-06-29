import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

const _presetIcons = [
  ('📶', 'WiFi'),
  ('🗑️', 'Bins'),
  ('🚗', 'Parking'),
  ('🔑', 'Keys'),
  ('🛒', 'Shops'),
  ('🚌', 'Transport'),
  ('🚨', 'Emergency'),
  ('🏠', 'House tips'),
  ('⚡', 'Utilities'),
  ('💧', 'Water'),
  ('🌿', 'Garden'),
  ('📋', 'General'),
];

class WelcomeGuideScreen extends StatelessWidget {
  const WelcomeGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final isLeaseholder = cu.role == 'leaseholder';
    final guide = state.welcomeGuide;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'Welcome guide',
            subtitle: 'Everything a new housemate needs to know.',
            action: isLeaseholder
                ? OutlinedButton(
                    onPressed: () => _editMessage(context, state, guide.message),
                    child: const Text('Edit message'),
                  )
                : null,
          ),

          if (guide.message.isNotEmpty) _WelcomeMessageCard(message: guide.message),

          if (guide.sections.isEmpty && guide.message.isEmpty)
            const EmptyState(title: 'No welcome guide yet'),

          for (final section in guide.sections)
            _SectionCard(
              section: section,
              isLeaseholder: isLeaseholder,
              onEdit: () => _editSection(context, state, section),
              onDelete: () => _deleteSection(context, state, section),
            ),

          if (isLeaseholder) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addSection(context, state),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add section'),
            ),
          ],

          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _editMessage(BuildContext context, HomiesState state, String current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MessageSheet(current: current, state: state),
    );
  }

  void _addSection(BuildContext context, HomiesState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SectionSheet(existing: null, state: state),
    );
  }

  void _editSection(BuildContext context, HomiesState state, WelcomeSection section) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SectionSheet(existing: section, state: state),
    );
  }

  Future<void> _deleteSection(
      BuildContext context, HomiesState state, WelcomeSection section) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('Delete "${section.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: HomiesColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      state.mutate(() =>
          state.welcomeGuide.sections.removeWhere((s) => s.id == section.id));
    }
  }
}

// ── Welcome message card ──────────────────────────────────────────────────────

class _WelcomeMessageCard extends StatelessWidget {
  final String message;
  const _WelcomeMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiesColors.accent.withValues(alpha: 0.07),
        border: Border.all(color: HomiesColors.accent.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('👋', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Welcome home!',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        SelectableText(
          message,
          style: const TextStyle(fontSize: 13, height: 1.6, color: HomiesColors.text),
        ),
      ]),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final WelcomeSection section;
  final bool isLeaseholder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SectionCard({
    required this.section,
    required this.isLeaseholder,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return HomiesCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (section.icon.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(section.icon, style: const TextStyle(fontSize: 20)),
            ),
          Expanded(
            child: Text(section.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (isLeaseholder) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 17, color: HomiesColors.textDim),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 17, color: HomiesColors.textDim),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
            ),
          ],
        ]),
        if (section.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            section.content,
            style: const TextStyle(
                fontSize: 13, color: HomiesColors.textDim, height: 1.6),
          ),
        ],
      ]),
    );
  }
}

// ── Welcome message editor sheet ─────────────────────────────────────────────

class _MessageSheet extends StatefulWidget {
  final String current;
  final HomiesState state;
  const _MessageSheet({required this.current, required this.state});

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Expanded(
                child: Text('Welcome message',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Write a welcome note for new housemates…',
              ),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  widget.state.mutate(
                      () => widget.state.welcomeGuide.message = _ctrl.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ]),
          ]),
    );
  }
}

// ── Section editor sheet ──────────────────────────────────────────────────────

class _SectionSheet extends StatefulWidget {
  final WelcomeSection? existing;
  final HomiesState state;
  const _SectionSheet({required this.existing, required this.state});

  @override
  State<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends State<_SectionSheet> {
  late TextEditingController _iconCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;

  @override
  void initState() {
    super.initState();
    _iconCtrl = TextEditingController(text: widget.existing?.icon ?? '');
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtrl.text.trim().isNotEmpty;

  void _pickPreset(String emoji, String label) {
    setState(() {
      _iconCtrl.text = emoji;
      if (_titleCtrl.text.isEmpty) _titleCtrl.text = label;
    });
  }

  void _save() {
    final state = widget.state;
    if (widget.existing != null) {
      state.mutate(() {
        widget.existing!.icon = _iconCtrl.text.trim();
        widget.existing!.title = _titleCtrl.text.trim();
        widget.existing!.content = _contentCtrl.text.trim();
      });
    } else {
      state.mutate(() {
        state.welcomeGuide.sections.add(WelcomeSection(
          id: 'wg-${Random().nextInt(0xFFFF).toRadixString(36)}',
          icon: _iconCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
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
                child: Text(isEdit ? 'Edit section' : 'Add section',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 10),
            const FieldLabel('Quick pick'),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (emoji, label) in _presetIcons)
                  ActionChip(
                    label: Text('$emoji $label',
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _pickPreset(emoji, label),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const FieldLabel('Icon'),
            TextField(
              controller: _iconCtrl,
              decoration: const InputDecoration(hintText: 'Emoji (e.g. 📶)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            const FieldLabel('Title'),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'e.g. WiFi details'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            const FieldLabel('Content'),
            TextField(
              controller: _contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'Instructions, notes, details…'),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _canSave ? _save : null,
                child: Text(isEdit ? 'Save changes' : 'Add section'),
              ),
            ]),
          ]),
    );
  }
}
