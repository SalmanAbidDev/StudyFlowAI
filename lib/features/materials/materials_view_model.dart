// lib/features/materials/materials_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';

/// The library, newest first.
final materialsProvider = FutureProvider<List<StudyMaterial>>(
  (ref) => ref.watch(libraryRepositoryProvider).materials(),
);

/// Which document the app is currently working on: set before pushing the
/// Document, Summaries, Flashcards or Quiz screens, so none of them has to
/// guess. Lives here rather than with Summaries — it answers a question about
/// the *library*, and four features read it.
final selectedMaterialProvider =
    NotifierProvider<ValueViewModel<String?>, String?>(
  () => ValueViewModel(null),
);

/// [selectedMaterialProvider] resolved against the library. Falls back to the
/// most recent document when nothing has been selected, so a screen opened
/// cold still has something to show.
final currentMaterialProvider = FutureProvider.autoDispose<StudyMaterial?>(
  (ref) async {
    final selectedId = ref.watch(selectedMaterialProvider);
    final all = await ref.watch(materialsProvider.future);
    if (selectedId == null) return all.firstOrNull;
    return all.where((m) => m.id == selectedId).firstOrNull;
  },
);

/// Title and subject search, shared by every list of materials in the app.
///
/// A plain function rather than a provider: the Materials tab keeps its query
/// in [materialsQueryProvider], but History and the pickers each own theirs —
/// typing in one must not filter the others.
List<StudyMaterial> filterMaterials(
  List<StudyMaterial> all,
  String rawQuery,
) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return all;
  // Title and subject both, so "chem" finds a document by its subject even
  // when the title never says it.
  return all
      .where((m) =>
          m.title.toLowerCase().contains(query) ||
          m.subjectName.toLowerCase().contains(query))
      .toList();
}

/// Index into [libraryFiltersProvider]; 0 is "All".
final materialsFilterProvider = NotifierProvider<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);

/// Built from the library rather than stored, so a count can never disagree
/// with the list beneath it.
final libraryFiltersProvider =
    Provider<List<({String label, int count})>>((ref) {
  final materials = ref.watch(materialsProvider).value ?? const [];
  final counts = <String, int>{};
  for (final material in materials) {
    counts[material.tag] = (counts[material.tag] ?? 0) + 1;
  }
  final tags = counts.keys.toList()..sort();
  return [
    (label: 'All', count: materials.length),
    for (final tag in tags) (label: tag, count: counts[tag]!),
  ];
});

/// What the user has typed into the search bar.
final materialsQueryProvider = NotifierProvider<ValueViewModel<String>, String>(
  () => ValueViewModel(''),
);

/// The filtered library the list actually renders: subject pill first, then
/// the search query.
final visibleMaterialsProvider = Provider<List<StudyMaterial>>((ref) {
  final materials = ref.watch(materialsProvider).value ?? const [];
  final filters = ref.watch(libraryFiltersProvider);
  final index = ref.watch(materialsFilterProvider);
  final query = ref.watch(materialsQueryProvider).trim().toLowerCase();

  var result = materials;

  // The filter index can outlive the list it indexed into — deleting the last
  // Chemistry material shortens the rail under a selection pointing past it.
  if (index > 0 && index < filters.length) {
    final tag = filters[index].label;
    result = result.where((m) => m.tag == tag).toList();
  }

  return filterMaterials(result, query);
});

/// True when the list is empty *because of* a filter or query rather than
/// because the library is. The two need different empty states — one is
/// "nothing matched", the other "nothing here yet".
final materialsFilteredToNothingProvider = Provider<bool>((ref) {
  final all = ref.watch(materialsProvider).value ?? const [];
  return all.isNotEmpty && ref.watch(visibleMaterialsProvider).isEmpty;
});

// ─── Multi-select ─────────────────────────────────────────────────────────

/// The ids currently ticked. **Empty means not in selection mode** — there is
/// no separate flag to keep in step with the set, which is the usual way this
/// goes wrong (a mode with nothing selected, or ticks with the mode off).
class MaterialSelection extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void start(String id) => state = {id};

  /// Unticking the last one leaves selection mode, the same way it does in the
  /// apps this is modelled on.
  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void clear() => state = const {};
}

final materialSelectionProvider =
    NotifierProvider<MaterialSelection, Set<String>>(MaterialSelection.new);

/// Whether the library is in selection mode at all. Derived, never stored.
final materialSelectionModeProvider =
    Provider<bool>((ref) => ref.watch(materialSelectionProvider).isNotEmpty);

/// The selected rows themselves, resolved against the live library so a
/// deleted-elsewhere id cannot survive as a ghost in the count.
final selectedMaterialsProvider = Provider<List<StudyMaterial>>((ref) {
  final ids = ref.watch(materialSelectionProvider);
  if (ids.isEmpty) return const [];
  final all = ref.watch(materialsProvider).value ?? const <StudyMaterial>[];
  return all.where((m) => ids.contains(m.id)).toList();
});

/// Removes materials and, where they came from an upload, their files.
///
/// The row goes first for each: the user asked for it to disappear from their
/// library, and that is the part they can see. A failed file delete leaves an
/// unreferenced object in the bucket — wasted space, but invisible and
/// harmless — whereas a failed row delete after removing the file would leave
/// a material that opens onto nothing.
///
/// Returns the ones that could not be deleted. A batch is not all-or-nothing,
/// and reporting "3 deleted" after two succeeded would be the wrong lie in the
/// wrong direction.
final deleteMaterialsProvider =
    Provider<Future<List<StudyMaterial>> Function(List<StudyMaterial>)>((ref) {
  return (materials) async {
    final failed = <StudyMaterial>[];

    for (final material in materials) {
      try {
        await ref.read(libraryRepositoryProvider).deleteMaterial(material.id);
      } catch (_) {
        failed.add(material);
        continue;
      }

      final path = material.storagePath;
      if (path != null) {
        try {
          await ref.read(storageRepositoryProvider).delete(path);
        } catch (_) {
          // Best effort — see above.
        }
      }
    }

    ref.invalidate(materialsProvider);
    return failed;
  };
});
