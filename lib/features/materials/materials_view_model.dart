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

/// The filtered library the list actually renders.
final visibleMaterialsProvider = Provider<List<StudyMaterial>>((ref) {
  final materials = ref.watch(materialsProvider).value ?? const [];
  final filters = ref.watch(libraryFiltersProvider);
  final index = ref.watch(materialsFilterProvider);

  // The filter index can outlive the list it indexed into — deleting the last
  // Chemistry material shortens the rail under a selection pointing past it.
  if (index <= 0 || index >= filters.length) return materials;

  final tag = filters[index].label;
  return materials.where((m) => m.tag == tag).toList();
});
