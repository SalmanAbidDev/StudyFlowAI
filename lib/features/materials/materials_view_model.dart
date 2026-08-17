// lib/features/materials/materials_view_model.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/view_models.dart';
import '../../data/models/study_material.dart';
import '../../data/supabase_providers.dart';

/// The library, newest first.
final materialsProvider = FutureProvider<List<StudyMaterial>>(
  (ref) => ref.watch(libraryRepositoryProvider).materials(),
);

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

  if (query.isNotEmpty) {
    // Title and subject both, so "chem" finds a document by its subject even
    // when the title never says it.
    result = result
        .where((m) =>
            m.title.toLowerCase().contains(query) ||
            m.subjectName.toLowerCase().contains(query))
        .toList();
  }

  return result;
});

/// True when the list is empty *because of* a filter or query rather than
/// because the library is. The two need different empty states — one is
/// "nothing matched", the other "nothing here yet".
final materialsFilteredToNothingProvider = Provider<bool>((ref) {
  final all = ref.watch(materialsProvider).value ?? const [];
  return all.isNotEmpty && ref.watch(visibleMaterialsProvider).isEmpty;
});

/// Removes a material and, if it came from an upload, its file.
///
/// The row goes first: the user asked for it to disappear from their library,
/// and that is the part they can see. A failed file delete leaves an
/// unreferenced object in the bucket — wasted space, but invisible and
/// harmless — whereas a failed row delete after removing the file would leave
/// a material that opens onto nothing.
final deleteMaterialProvider =
    Provider<Future<void> Function(StudyMaterial)>((ref) {
  return (material) async {
    await ref.read(libraryRepositoryProvider).deleteMaterial(material.id);

    final path = material.storagePath;
    if (path != null) {
      try {
        await ref.read(storageRepositoryProvider).delete(path);
      } catch (_) {
        // Best effort — see above.
      }
    }

    ref.invalidate(materialsProvider);
  };
});
