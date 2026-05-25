import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/avatar.dart';
import '../widgets/file_picker_button.dart';
import '../widgets/ui_kit.dart';

const _categories = [
  ['plumbing', '🚿 Plumbing'],
  ['appliance', '🧊 Appliance'],
  ['electrical', '💡 Electrical'],
  ['structure', '🏠 Structure'],
  ['pest', '🐜 Pest'],
  ['other', '📌 Other'],
];

String _categoryLabel(String key) =>
    _categories.firstWhere((c) => c[0] == key, orElse: () => ['other', '📌 Other'])[1];

class IssuesScreen extends StatelessWidget {
  const IssuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;
    final open = state.issues.where((i) => i.status == 'open').toList();
    final fixed = state.issues.where((i) => i.status == 'fixed').toList();

    void openModal(Issue? existing) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _IssueModal(existing: existing),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHead(
            title: 'House issues',
            subtitle: 'Broken stuff, leaks, dodgy appliances — anyone can raise an issue and mark it fixed.',
            action: ElevatedButton(onPressed: () => openModal(null), child: const Text('+ Raise')),
          ),
          if (state.issues.isEmpty)
            const EmptyState(title: 'No issues raised', body: 'Tap "Raise" when something needs fixing.'),
          if (open.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text('Open · ${open.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final i in open)
              _IssueCard(
                issue: i,
                canEdit: i.raisedBy == cu.id,
                onEdit: () => openModal(i),
                onDelete: () => _confirmDelete(context, state, i),
                onFix: () => _markFixed(state, i, cu.id),
              ),
          ],
          if (fixed.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text('Fixed · ${fixed.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            for (final i in fixed)
              _IssueCard(
                issue: i,
                canEdit: i.raisedBy == cu.id,
                onEdit: () => openModal(i),
                onDelete: () => _confirmDelete(context, state, i),
                onReopen: () => _reopen(state, i),
              ),
          ],
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, HomiesState state, Issue issue) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text('Delete "${issue.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      state.mutate(() => state.issues.removeWhere((x) => x.id == issue.id));
    }
  }

  void _markFixed(HomiesState state, Issue issue, String userId) {
    state.mutate(() {
      issue.status = 'fixed';
      issue.fixedAt = todayIso();
      issue.fixedBy = userId;
    });
  }

  void _reopen(HomiesState state, Issue issue) {
    state.mutate(() {
      issue.status = 'open';
      issue.fixedAt = null;
      issue.fixedBy = null;
    });
  }
}

class _IssueCard extends StatelessWidget {
  final Issue issue;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onFix;
  final VoidCallback? onReopen;
  const _IssueCard({
    required this.issue,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    this.onFix,
    this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final raisedBy = state.findUser(issue.raisedBy);
    final fixedBy = issue.fixedBy != null ? state.findUser(issue.fixedBy) : null;
    final isOpen = issue.status == 'open';

    return HomiesCard(
      color: isOpen ? HomiesColors.surface : HomiesColors.surface2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                HomiesChip(isOpen ? 'open' : 'fixed', tone: isOpen ? ChipTone.warn : ChipTone.ok),
                HomiesChip(_categoryLabel(issue.category)),
              ]),
              const SizedBox(height: 2),
              Text(
                'Raised by ${raisedBy?.name ?? '—'} · ${fmtDate(issue.raisedAt)}'
                '${!isOpen && fixedBy != null ? ' · fixed by ${fixedBy.name} on ${fmtDate(issue.fixedAt)}' : ''}',
                style: const TextStyle(color: HomiesColors.textDim, fontSize: 12),
              ),
              if (issue.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(issue.description, style: const TextStyle(fontSize: 13)),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          if (raisedBy != null) Avatar.sm(raisedBy),
        ]),
        if (issue.photo != null) AttachmentTile(value: issue.photo!, compact: true),
        const SizedBox(height: 4),
        Wrap(spacing: 6, alignment: WrapAlignment.end, children: [
          if (canEdit)
            TextButton(
              onPressed: onDelete,
              child: const Text('Delete', style: TextStyle(color: HomiesColors.danger)),
            ),
          if (canEdit) OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
          if (isOpen && onFix != null)
            ElevatedButton(onPressed: onFix, child: const Text('✓ Mark fixed'))
          else if (!isOpen && onReopen != null)
            OutlinedButton(onPressed: onReopen, child: const Text('Reopen')),
        ]),
      ]),
    );
  }
}

class _IssueModal extends StatefulWidget {
  final Issue? existing;
  const _IssueModal({this.existing});

  @override
  State<_IssueModal> createState() => _IssueModalState();
}

class _IssueModalState extends State<_IssueModal> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String category = 'other';
  Attachment? photo;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      titleCtrl.text = e.title;
      descCtrl.text = e.description;
      category = e.category;
      photo = e.photo;
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _save(HomiesState state) {
    final isEdit = widget.existing != null;
    state.mutate(() {
      if (isEdit) {
        final i = widget.existing!;
        i.title = titleCtrl.text.trim();
        i.category = category;
        i.description = descCtrl.text.trim();
        i.photo = photo;
      } else {
        state.issues.insert(0, Issue(
          id: 'is-${Random().nextInt(0xFFFF).toRadixString(36)}',
          title: titleCtrl.text.trim(),
          category: category,
          description: descCtrl.text.trim(),
          photo: photo,
          raisedBy: state.currentUser?.id ?? '',
          raisedAt: todayIso(),
        ));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final isEdit = widget.existing != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text(isEdit ? 'Edit issue' : 'Raise a house issue',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const FieldLabel('Title'),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(hintText: 'Leaking shower tap'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              const FieldLabel('Category'),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: [for (final c in _categories) DropdownMenuItem(value: c[0], child: Text(c[1]))],
                onChanged: (v) => setState(() => category = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              const FieldLabel('Description (optional)'),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Where, when, how bad.'),
              ),
              const SizedBox(height: 10),
              const FieldLabel('Photo (optional)'),
              FilePickerButton(value: photo, onChanged: (v) => setState(() => photo = v), label: 'Choose image'),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: titleCtrl.text.trim().isEmpty ? null : () => _save(state),
                  child: Text(isEdit ? 'Save changes' : 'Raise issue'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
