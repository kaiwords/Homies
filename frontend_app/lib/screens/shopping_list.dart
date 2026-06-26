import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../state/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui_kit.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addItem(HomiesState state) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final cu = state.currentUser!;
    state.mutate(() {
      state.shoppingList.add(ShoppingItem(
        id: 'si_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        addedBy: cu.id,
        addedByName: cu.name,
        addedAt: DateTime.now().toIso8601String(),
      ));
    });
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _toggleDone(HomiesState state, ShoppingItem item) {
    final cu = state.currentUser!;
    state.mutate(() {
      item.done = !item.done;
      if (item.done) {
        item.doneBy = cu.id;
        item.doneByName = cu.name;
        item.doneAt = DateTime.now().toIso8601String();
      } else {
        item.doneBy = null;
        item.doneByName = null;
        item.doneAt = null;
      }
    });
  }

  void _deleteItem(HomiesState state, String id) {
    state.mutate(() => state.shoppingList.removeWhere((i) => i.id == id));
  }

  void _clearGot(HomiesState state) {
    state.mutate(() => state.shoppingList.removeWhere((i) => i.done));
  }

  @override
  Widget build(BuildContext context) {
    final state = HomiesScope.of(context);
    final cu = state.currentUser!;

    final needed = state.shoppingList.where((i) => !i.done).toList()
      ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    final got = state.shoppingList.where((i) => i.done).toList()
      ..sort((a, b) => (b.doneAt ?? '').compareTo(a.doneAt ?? ''));

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                const PageHead(
                  title: 'Shopping List',
                  subtitle: 'Add what you need — housemates tick items off at the shop.',
                ),
                if (state.shoppingList.isEmpty)
                  const _EmptyHint()
                else ...[
                  if (needed.isEmpty && got.isNotEmpty)
                    _AllDoneRow(),
                  for (final item in needed)
                    _ItemTile(
                      key: ValueKey(item.id),
                      item: item,
                      cu: cu,
                      state: state,
                      onToggle: () => _toggleDone(state, item),
                      onDelete: () => _deleteItem(state, item.id),
                    ),
                  if (got.isNotEmpty) ...[
                    _GotHeader(count: got.length, onClearAll: () => _clearGot(state)),
                    for (final item in got)
                      _ItemTile(
                        key: ValueKey(item.id),
                        item: item,
                        cu: cu,
                        state: state,
                        onToggle: () => _toggleDone(state, item),
                        onDelete: () => _deleteItem(state, item.id),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: _AddBar(ctrl: _ctrl, focus: _focus, onAdd: () => _addItem(state)),
        ),
      ],
    );
  }
}

// ─── Empty / all-done states ──────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 48, color: HomiesColors.textFaint),
          SizedBox(height: 12),
          Text(
            'Nothing on the list yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomiesColors.textDim),
          ),
          SizedBox(height: 4),
          Text(
            'Type below to add items for your next shop.',
            style: TextStyle(fontSize: 13, color: HomiesColors.textFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AllDoneRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.check_circle_outline, color: HomiesColors.ok, size: 18),
        SizedBox(width: 6),
        Text(
          'All items picked up!',
          style: TextStyle(color: HomiesColors.ok, fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ]),
    );
  }
}

class _GotHeader extends StatelessWidget {
  final int count;
  final VoidCallback onClearAll;
  const _GotHeader({required this.count, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
      child: Row(children: [
        Expanded(
          child: Text(
            'GOT · $count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HomiesColors.textFaint,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextButton(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: HomiesColors.danger,
          ),
          child: const Text('Clear all', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

// ─── Item tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ShoppingItem item;
  final User cu;
  final HomiesState state;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ItemTile({
    super.key,
    required this.item,
    required this.cu,
    required this.state,
    required this.onToggle,
    required this.onDelete,
  });

  bool get _canDelete => cu.isLeaseholder || item.addedBy == cu.id;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: item.done ? HomiesColors.surface2 : HomiesColors.surface,
          border: Border.all(color: item.done ? HomiesColors.border : HomiesColors.borderStrong),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              item.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: item.done ? HomiesColors.ok : HomiesColors.textFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: item.done ? HomiesColors.textFaint : HomiesColors.text,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                      decorationColor: HomiesColors.textFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (item.done)
                    Text(
                      'Got by ${item.doneByName ?? '?'} · ${fmtDateShort(item.doneAt)}',
                      style: const TextStyle(fontSize: 11, color: HomiesColors.ok),
                    )
                  else
                    Text(
                      'Added by ${item.addedByName} · ${fmtRelative(item.addedAt)}',
                      style: const TextStyle(fontSize: 11, color: HomiesColors.textFaint),
                    ),
                ],
              ),
            ),
            if (_canDelete)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: HomiesColors.textFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick-add bar ────────────────────────────────────────────────────────────

class _AddBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final VoidCallback onAdd;

  const _AddBar({required this.ctrl, required this.focus, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: HomiesColors.surface,
        border: Border(top: BorderSide(color: HomiesColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            decoration: const InputDecoration(
              hintText: 'Add an item…',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.add_circle_rounded, size: 30),
          color: HomiesColors.accent,
          visualDensity: VisualDensity.compact,
          tooltip: 'Add item',
          onPressed: onAdd,
        ),
      ]),
    );
  }
}
