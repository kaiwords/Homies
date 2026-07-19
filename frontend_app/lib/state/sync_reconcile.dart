import 'dart:convert';

/// Result of reconciling one in-memory collection against the baseline we
/// believe Firestore currently holds. Produced by [reconcileCollection] and
/// consumed by the per-collection push in `HomiesState`.
class CollectionDiff {
  /// docId -> document JSON to `set()` — records that were added or changed
  /// locally AND that the current user is allowed to write.
  final Map<String, Map<String, dynamic>> toWrite;

  /// docIds to `delete()` — records present in the baseline, gone from the
  /// local list, AND that the current user is allowed to delete.
  final List<String> toDelete;

  const CollectionDiff(this.toWrite, this.toDelete);

  bool get isEmpty => toWrite.isEmpty && toDelete.isEmpty;
}

/// Pure, side-effect-free reconciliation for one per-record Firestore
/// collection. Factored out of the sync so it can be unit-tested in isolation.
///
/// - [baseline] maps docId -> the serialized JSON we last observed from (or
///   wrote to) Firestore. It is canonicalised as `jsonEncode(model.toJson())`,
///   the exact same form [current] is compared against, so equal content never
///   registers as a change.
/// - [current] is the in-memory list, each entry the model's `toJson()` map
///   (which always carries its own `id`).
/// - [canWrite] returns true only for docs the current user may create/update
///   (public: owner; scoped: participant; notifications: anyone).
/// - [canDelete] returns true only for docs the current user may delete.
///
/// Records the user can neither write nor delete — other people's docs received
/// via the collection listeners — are never returned: the Firestore rules would
/// reject those writes anyway, so attempting them would be pointless noise.
CollectionDiff reconcileCollection({
  required Map<String, String> baseline,
  required List<Map<String, dynamic>> current,
  required bool Function(Map<String, dynamic> json) canWrite,
  required bool Function(Map<String, dynamic> json) canDelete,
}) {
  final toWrite = <String, Map<String, dynamic>>{};
  final currentIds = <String>{};

  for (final json in current) {
    final id = (json['id'] ?? '') as String;
    if (id.isEmpty) continue;
    currentIds.add(id);
    if (!canWrite(json)) continue; // never write docs we don't own/participate in
    if (baseline[id] != jsonEncode(json)) {
      toWrite[id] = json; // new (absent from baseline) or content changed
    }
  }

  final toDelete = <String>[];
  for (final entry in baseline.entries) {
    if (currentIds.contains(entry.key)) continue; // still present locally
    Map<String, dynamic> json;
    try {
      json = jsonDecode(entry.value) as Map<String, dynamic>;
    } catch (_) {
      continue; // unparseable baseline entry — leave the remote doc untouched
    }
    if (canDelete(json)) toDelete.add(entry.key); // only delete our own
  }

  return CollectionDiff(toWrite, toDelete);
}
