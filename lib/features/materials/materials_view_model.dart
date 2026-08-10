// lib/state/materials_state.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo_content.dart';
import '../../core/view_models.dart';

/// Index into [demoLibraryFilters]; 0 is "All".
final materialsFilterProvider = NotifierProvider<ValueViewModel<int>, int>(
  () => ValueViewModel(0),
);

/// The filtered library. Derived rather than recomputed in the widget, so the
/// filtering rule lives next to the filter it depends on.
final visibleMaterialsProvider = Provider<List<StudyMaterial>>((ref) {
  final filter = ref.watch(materialsFilterProvider);
  if (filter == 0) return demoMaterials;
  final tag = demoLibraryFilters[filter].label;
  return demoMaterials.where((m) => m.tag == tag).toList();
});
