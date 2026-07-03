import 'package:flutter/material.dart';

import '../theme.dart';

/// A bottom sheet for picking which categories a user wants to see in a
/// chip-filtered browse screen (Essentials, Marketplace) — pick between [min]
/// and [max] categories, with a reset-to-all option. [categories] should
/// exclude the synthetic 'all' entry.
class CategoryPrefsSheet extends StatefulWidget {
  final List<(String, String, IconData)> categories;
  final List<String> initial;
  final int min;
  final int max;
  final ValueChanged<List<String>> onSave;
  const CategoryPrefsSheet({
    super.key,
    required this.categories,
    required this.initial,
    required this.min,
    required this.max,
    required this.onSave,
  });

  @override
  State<CategoryPrefsSheet> createState() => _CategoryPrefsSheetState();
}

class _CategoryPrefsSheetState extends State<CategoryPrefsSheet> {
  late final Set<String> _selected = widget.initial.toSet();

  @override
  Widget build(BuildContext context) {
    final canSave = _selected.length >= widget.min && _selected.length <= widget.max;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: HomiesColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Choose your categories',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomiesColors.text)),
          const SizedBox(height: 4),
          Text(
            'Pick ${widget.min} to ${widget.max} categories to show — ${_selected.length}/${widget.max} selected.',
            style: TextStyle(
              fontSize: 12,
              color: _selected.length < widget.min ? HomiesColors.danger : HomiesColors.textDim,
            ),
          ),
          const SizedBox(height: 8),
          for (final cat in widget.categories)
            CheckboxListTile(
              value: _selected.contains(cat.$1),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (_selected.length < widget.max) _selected.add(cat.$1);
                  } else {
                    _selected.remove(cat.$1);
                  }
                });
              },
              secondary: Icon(cat.$3, size: 18, color: HomiesColors.textDim),
              title: Text(cat.$2),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canSave
                ? () {
                    widget.onSave(_selected.toList());
                    Navigator.pop(context);
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: HomiesColors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Save'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed: () {
                  widget.onSave([]);
                  Navigator.pop(context);
                },
                child: const Text('Reset — show all categories'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
